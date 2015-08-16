//
//  XCDYouTubeClient.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/7/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import XCDYouTubeKit
import ReactiveCocoa
import Result
import Box
import Alamofire
import SwiftyJSON
import NXOAuth2Client

extension XCDYouTubeClient {
    func fetchVideo(identifier: String) -> SignalProducer<XCDYouTubeVideo, NSError> {
        return SignalProducer { (sink, disposable) in
            let operation = self.getVideoWithIdentifier(identifier, completionHandler: { (video, error) -> Void in
                if let e = error {
                    sink.put(.Error(Box(error)))
                    return
                }
                sink.put(.Next(Box(video)))
                sink.put(.Completed)
            })
            disposable.addDisposable {
                operation.cancel()
            }
            return
        }
    }
}

public class YouTubeAPIClient {
    static var sharedInstance = YouTubeAPIClient()
    static var clientId       = ""
    static var clientSecret   = ""
    static var baseUrl        = "https://accounts.google.com"
    static var authUrl        = "\(baseUrl)/o/oauth2/auth"
    static var tokenUrl       = "\(baseUrl)/o/oauth2/token"
    static var scopeUrl       = "https://gdata.youtube.com"
    static var redirectUrl    = "http://localhost/"
    static var accountType    = "YouTube"
    static var keyChainGroup  = "YouTube"
    static var API_KEY        = ""
    var API_KEY: String { return YouTubeAPIClient.API_KEY }
    var oauth2clientDelegate: YouTubeOAuth2ClientDelegate

    static var _account: NXOAuth2Account?
    static var account: NXOAuth2Account? {
        if let a = _account {
            return a
        }
        let store = NXOAuth2AccountStore.sharedStore() as! NXOAuth2AccountStore
        for account in store.accounts as! [NXOAuth2Account] {
            if account.accountType == "YouTube" {
                _account = account
                return account
            }
        }
        return nil
    }

    static var isLoggedIn: Bool {
        return account != nil
    }

    static func refreshAccount(account: NXOAuth2Account) {
        clearAllAccount()
        let store = NXOAuth2AccountStore.sharedStore() as! NXOAuth2AccountStore
        store.addAccount(account)
    }

    static func clearAllAccount() {
        let store = NXOAuth2AccountStore.sharedStore() as! NXOAuth2AccountStore
        for account in store.accounts as! [NXOAuth2Account] {
            if account.accountType == "YouTube" {
                store.removeAccount(account)
            }
        }
        _account = nil
    }

    static var accessToken: String? {
        if let token = account?.accessToken.accessToken {
            return token
        }
        return nil
    }

    private static func loadConfig() {
        let bundle = NSBundle.mainBundle()
        if let path = bundle.pathForResource("youtube", ofType: "json") {
            let data = NSData(contentsOfFile: path)
            let jsonObject: AnyObject? = NSJSONSerialization.JSONObjectWithData(data!,
                options: NSJSONReadingOptions.MutableContainers,
                error: nil)
            if let obj: AnyObject = jsonObject {
                let json = JSON(obj)
                if let apiKey = json["api_key"].string {
                    API_KEY = apiKey
                }
                if let id = json["client_id"].string {
                    clientId = id
                }
                if let secret = json["client_secret"].string {
                    clientSecret = secret
                }
            }
        }
    }

    public static func setup() {
        loadConfig()
    }

    init() {
        typealias Y = YouTubeAPIClient
        oauth2clientDelegate = YouTubeOAuth2ClientDelegate()
    }

    var oauth2client: NXOAuth2Client? {
        typealias Y = YouTubeAPIClient
        if let accessToken = Y.account?.accessToken {
            return NXOAuth2Client(clientID: Y.clientId,
                              clientSecret: Y.clientSecret,
                              authorizeURL: NSURL(string: Y.authUrl)!,
                                  tokenURL: NSURL(string: Y.tokenUrl)!,
                               accessToken: accessToken,
                             keyChainGroup: Y.keyChainGroup,
                                persistent: true,
                                 delegate: oauth2clientDelegate)
        } else {
            return nil
        }
    }

    static func newManager() -> Manager {
        var m = Alamofire.Manager()
        if let token = YouTubeAPIClient.accessToken {
            m.session.configuration.HTTPAdditionalHeaders = ["Authorization": "Bearer \(token)"]
        }
        return m
    }

    func request(method: Alamofire.Method, URLString: URLStringConvertible, parameters: [String : AnyObject]?, encoding: ParameterEncoding, callback: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Alamofire.Request {
        let request = YouTubeAPIClient.newManager().request(method, URLString, parameters: parameters, encoding: encoding)
            .validate(statusCode: 200..<300)
            .validate(contentType: ["application/json"])
            .responseJSON(options: NSJSONReadingOptions.allZeros) { (req, res, obj, error) -> Void in
                if let e = error {
                    if let oauth2client = self.oauth2client {
                        self.oauth2clientDelegate.addPendingRequest(req, callback: callback)
                        oauth2client.refreshAccessToken()
                        return
                    }
                }
                callback((req, res, obj, error))
        }
        return request
    }

    func fetchGuideCategories(pageToken: String?) -> SignalProducer<(items: [GuideCategory], nextPageToken: String?), NSError> {
        return SignalProducer { (sink, disposable) in
            let url = "https://www.googleapis.com/youtube/v3/guideCategories"
            var params: [String: AnyObject]
            if let token = pageToken {
                params = ["key": self.API_KEY, "part": "snippet", "maxResults": 10, "regionCode": "JP", "pageToken": token]
            } else {
                params = ["key": self.API_KEY, "part": "snippet", "maxResults": 10, "regionCode": "JP"]
            }

            let request = self.request(.GET, URLString: url, parameters: params, encoding: .URL) { (req, res, obj, error) in
                if let e = error {
                    YouTubeAPIClient.clearAllAccount()
                    sink.put(.Error(Box(e)))
                } else {
                    let json = JSON(obj!)
                    let val  = (items: json["items"].arrayValue.map { GuideCategory(json: $0) },
                        nextPageToken: json["nextPageToken"].string)
                    sink.put(.Next(Box(val)))
                    sink.put(.Completed)
                }
            }
            disposable.addDisposable {
                request.cancel()
            }
        }
    }

    func fetchChannels(category: GuideCategory, pageToken: String?) -> SignalProducer<(items: [Channel], nextPageToken: String?), NSError> {
        if let token = pageToken {
            return fetch(["categoryId": category.id, "pageToken": token])
        } else {
            return fetch(["categoryId": category.id])
        }
    }

    func fetchSubscriptions(pageToken: String?) -> SignalProducer<(items: [YouTubeSubscription], nextPageToken: String?), NSError> {
        if let token = pageToken {
            return fetch(["mine": "true", "pageToken": token])
        } else {
            return fetch(["mine": "true"])
        }
    }

    func searchChannel(query: String?, pageToken: String?) -> SignalProducer<(items: [Channel], nextPageToken: String?), NSError> {
        return SignalProducer { (sink, disposable) in
            let url = "https://www.googleapis.com/youtube/v3/search"
            var params: [String: AnyObject] = ["key": self.API_KEY,
                                              "part": "snippet",
                                        "maxResults": 10,
                                        "regionCode": "JP",
                                              "type": "channel",
                                       "channelType": "any"]
            if let token = pageToken {
                params["pageToken"] = token
            }
            if let q = query {
                params["q"] = q
            }
            let request = self.request(.GET, URLString: url, parameters: params, encoding: .URL) { (req, res, obj, error) in
                if let e = error {
                    YouTubeAPIClient.clearAllAccount()
                    sink.put(.Error(Box(e)))
                } else {
                    let json = JSON(obj!)
                    let val  = (items: json["items"].arrayValue.map { Channel(json: $0) },
                        nextPageToken: json["nextPageToken"].string)
                    sink.put(.Next(Box(val)))
                    sink.put(.Completed)
                }
            }
            disposable.addDisposable {
                request.cancel()
            }
        }
    }

    func fetch<T: YouTubeResource>(params: [String:String]) -> SignalProducer<(items: [T], nextPageToken: String?), NSError> {
        return SignalProducer { (sink, disposable) in
            var _params: [String: AnyObject] = ["key": self.API_KEY,
                                               "part": "snippet",
                                         "maxResults": 10]
            for k in params.keys {
                _params[k] = params[k]
            }
            let request = self.request(.GET, URLString: T.url, parameters: _params, encoding: .URL) { (req, res, obj, error) in
                if let e = error {
                    sink.put(.Error(Box(e)))
                } else {
                    let json = JSON(obj!)
                    let val  = (items: json["items"].arrayValue.map { T(json: $0) },
                        nextPageToken: json["nextPageToken"].string)
                    sink.put(.Next(Box(val)))
                    sink.put(.Completed)
                }
            }
            disposable.addDisposable {
                request.cancel()
            }
        }
    }
    func fetchPlaylists(pageToken: String?) -> SignalProducer<(items: [YouTubePlaylist], nextPageToken: String?), NSError> {
        if let token = pageToken {
            return fetch(["pageToken":token])
        } else {
            return fetch([:])
        }
    }
}

public class YouTubeOAuth2ClientDelegate: NSObject, NXOAuth2ClientDelegate {
    public typealias RequestCallback = (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void
    public var pendingRequests: [(NSURLRequest, RequestCallback)]
    public override init() {
        pendingRequests = []
    }
    func addPendingRequest(request: NSURLRequest, callback: RequestCallback) {
        pendingRequests.append((request, callback))
    }
    func restartPendingRequests() {
        for req in pendingRequests {
            YouTubeAPIClient.newManager()
                .request(req.0)
                .responseJSON(options: NSJSONReadingOptions.allZeros,
                    completionHandler: req.1)
        }
        pendingRequests = []
    }
    public func oauthClientNeedsAuthentication(client: NXOAuth2Client!) {}
    public func oauthClientDidGetAccessToken(client: NXOAuth2Client!) {}
    public func oauthClient(client: NXOAuth2Client!, didFailToGetAccessTokenWithError error: NSError!) {
        restartPendingRequests()
    }
    public func oauthClientDidLoseAccessToken(client: NXOAuth2Client!) {
        restartPendingRequests()
    }
    public func oauthClientDidRefreshAccessToken(client: NXOAuth2Client!) {
        YouTubeAPIClient.refreshAccount(NXOAuth2Account(accountWithAccessToken: client.accessToken,
                                                                   accountType: YouTubeAPIClient.accountType))
        restartPendingRequests()
    }
}
