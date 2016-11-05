//
//  XCDYouTubeClient.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/7/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import XCDYouTubeKit
import ReactiveSwift
import Result
import Alamofire
import SwiftyJSON
import NXOAuth2Client

extension XCDYouTubeClient {
    func fetchVideo(_ identifier: String) -> SignalProducer<XCDYouTubeVideo, NSError> {
        return SignalProducer { (observer, disposable) in
            let operation = self.getVideoWithIdentifier(identifier, completionHandler: { (video, error) -> Void in
                if let e = error {
                    observer.send(error: e as NSError)
                    return
                } else if let v = video {
                    observer.send(value: v)
                    observer.sendCompleted()
                }
            })
            disposable.add {
                operation.cancel()
            }
            return
        }
    }
}

open class YouTubeAPIClient {
    static var sharedInstance = YouTubeAPIClient()
    static var clientId       = ""
    static var clientSecret   = ""
    static var baseUrl        = "https://accounts.google.com"
    static var authUrl        = "\(baseUrl)/o/oauth2/auth"
    static var tokenUrl       = "\(baseUrl)/o/oauth2/token"
    static var scope          = Set(["https://gdata.youtube.com"])
    static var redirectUrl    = "http://localhost/"
    static var accountType    = "YouTube"
    static var keyChainGroup  = "YouTube"
    static var API_KEY        = ""
    var API_KEY: String { return YouTubeAPIClient.API_KEY }
    var oauth2clientDelegate: YouTubeOAuth2ClientDelegate

    var manager: Alamofire.SessionManager = Alamofire.SessionManager()

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

    static func refreshAccount(_ account: NXOAuth2Account) {
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

    fileprivate static func loadConfig() {
        let bundle = Bundle.main
        if let path = bundle.path(forResource: "youtube", ofType: "json") {
            let data = try? Data(contentsOf: URL(fileURLWithPath: path))
            let jsonObject: AnyObject? = try! JSONSerialization.jsonObject(with: data!,
                options: JSONSerialization.ReadingOptions.mutableContainers) as AnyObject?
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

    open static func setup() {
        loadConfig()
        sharedInstance.renewManager()
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
                              authorizeURL: URL(string: Y.authUrl)!,
                                  tokenURL: URL(string: Y.tokenUrl)!,
                               accessToken: accessToken,
                             keyChainGroup: Y.keyChainGroup,
                                persistent: true,
                                 delegate: oauth2clientDelegate)
        } else {
            return nil
        }
    }

    func renewManager() {
        let configuration = manager.session.configuration
        var headers = configuration.httpAdditionalHeaders ?? [:]
        if let token = YouTubeAPIClient.accessToken {
            headers["Authorization"] = "Bearer \(token)"
        } else {
            headers.removeValue(forKey: "Authorization")
        }
        configuration.httpAdditionalHeaders = headers
        manager = Alamofire.SessionManager(configuration: configuration)
    }

    func request(_ url: URLConvertible, method: HTTPMethod, parameters: [String : Any]?, encoding: ParameterEncoding, callback: @escaping (DataResponse<Any>) -> Void) -> Alamofire.Request {
        let request = manager.request(url, method: method, parameters: parameters, encoding: encoding)
            .validate(statusCode: 200..<300)
            .validate(contentType: ["application/json"])
            .responseJSON(options: .allowFragments) { response in
                if let r = response.request {
                    if response.result.isFailure {
                        if let oauth2client = self.oauth2client {
                            self.oauth2clientDelegate.addPendingRequest(r, callback: callback)
                            oauth2client.refreshAccessToken()
                            return
                        }
                    }
                }
                callback(response)
        }
        return request
    }

    func fetchGuideCategories(_ pageToken: String?) -> SignalProducer<(items: [GuideCategory], nextPageToken: String?), NSError> {
        return SignalProducer { (observer, disposable) in
            let url = "https://www.googleapis.com/youtube/v3/guideCategories"
            var params: [String: Any]
            if let token = pageToken {
                params = ["key": self.API_KEY
                    , "part": "snippet", "maxResults": 10, "regionCode": "JP", "pageToken": token]
            } else {
                params = ["key": self.API_KEY, "part": "snippet", "maxResults": 10, "regionCode": "JP"]
            }

            let request = self.request(url, method: .get, parameters: params, encoding: URLEncoding.default) { response in
                if let e = response.result.error {
                    YouTubeAPIClient.clearAllAccount()
                    observer.send(error: e as NSError)
                } else if let obj = response.result.value {
                    let json = JSON(obj)
                    let val  = (items: json["items"].arrayValue.map { GuideCategory(json: $0) },
                        nextPageToken: json["nextPageToken"].string)
                    observer.send(value: val)
                    observer.sendCompleted()
                }
            }
            disposable.add {
                request.cancel()
            }
        }
    }

    func fetchMyChannels(_ pageToken: String?) -> SignalProducer<(items: [MyChannel], nextPageToken: String?), NSError> {
        if let token = pageToken {
            return fetch(["part": "snippet, contentDetails", "mine": "true", "pageToken": token])
        } else {
            return fetch(["part": "snippet, contentDetails", "mine": "true"])
        }
    }

    func fetchChannels(_ category: GuideCategory, pageToken: String?) -> SignalProducer<(items: [Channel], nextPageToken: String?), NSError> {
        if let token = pageToken {
            return fetch(["categoryId": category.id, "pageToken": token])
        } else {
            return fetch(["categoryId": category.id])
        }
    }

    func fetchSubscriptions(_ pageToken: String?) -> SignalProducer<(items: [YouTubeSubscription], nextPageToken: String?), NSError> {
        if let token = pageToken {
            return fetch(["mine": "true", "pageToken": token])
        } else {
            return fetch(["mine": "true"])
        }
    }

    func searchChannel(_ query: String?, pageToken: String?) -> SignalProducer<(items: [Channel], nextPageToken: String?), NSError> {
        return SignalProducer { (observer, disposable) in
            let url = "https://www.googleapis.com/youtube/v3/search"
            var params: [String: Any] = ["key": self.API_KEY as AnyObject,
                                        "part": "snippet" as AnyObject,
                                  "maxResults": 10 as AnyObject,
                                  "regionCode": "JP" as AnyObject,
                                        "type": "channel" as AnyObject,
                                 "channelType": "any" as AnyObject]
            if let token = pageToken {
                params["pageToken"] = token as Any?
            }
            if let q = query {
                params["q"] = q as Any?
            }
            let request = self.request(url, method: .get, parameters: params, encoding: URLEncoding.default) { response in
                if let e = response.result.error {
                    YouTubeAPIClient.clearAllAccount()
                    observer.send(error: e as NSError)
                } else if let obj = response.result.value {
                    let json = JSON(obj)
                    let val  = (items: json["items"].arrayValue.map { Channel(json: $0) },
                        nextPageToken: json["nextPageToken"].string)
                    observer.send(value: val)
                    observer.sendCompleted()
                }
            }
            disposable.add {
                request.cancel()
            }
        }
    }

    func fetch<T: YouTubeResource>(_ params: [String:String]) -> SignalProducer<(items: [T], nextPageToken: String?), NSError> {
        return SignalProducer { (observer, disposable) in
            var _params: [String: AnyObject] = ["key": self.API_KEY as AnyObject,
                                               "part": "snippet" as AnyObject,
                                         "maxResults": 10 as AnyObject]
            for k in params.keys {
                _params[k] = params[k] as AnyObject?
            }
            let request = self.request(T.url, method: .get, parameters: _params, encoding: URLEncoding.default) { response in
                if let e = response.result.error {
                    observer.send(error: e as NSError)
                } else if let obj = response.result.value {
                    let json = JSON(obj)
                    let val  = (items: json["items"].arrayValue.map { T(json: $0) },
                        nextPageToken: json["nextPageToken"].string)
                    observer.send(value: val)
                    observer.sendCompleted()
                }
            }
            disposable.add {
                request.cancel()
            }
        }
    }
    func fetchPlaylists(_ pageToken: String?) -> SignalProducer<(items: [YouTubePlaylist], nextPageToken: String?), NSError> {
        if let token = pageToken {
            return fetch(["pageToken": token, "mine": "true"])
        } else {
            return fetch(["mine": "true"])
        }
    }

    func fetchPlaylistItems(_ id: String, pageToken: String?) -> SignalProducer<(items: [YouTubePlaylistItem], nextPageToken: String?), NSError> {
        if let token = pageToken {
            return fetch(["pageToken": token, "playlistId": id, "part": "snippet, contentDetails"])
        } else {
            return fetch(["playlistId": id, "part": "snippet, contentDetails"])
        }
    }

    func fetchPlaylistItems(_ playlist: YouTubePlaylist, pageToken: String?) -> SignalProducer<(items: [YouTubePlaylistItem], nextPageToken: String?), NSError> {
        return fetchPlaylistItems(playlist.id, pageToken: pageToken)
    }
}

open class YouTubeOAuth2ClientDelegate: NSObject, NXOAuth2ClientDelegate {
    public typealias RequestCallback = (DataResponse<Any>) -> Void
    open var pendingRequests: [(URLRequest, RequestCallback)]
    public override init() {
        pendingRequests = []
    }
    func addPendingRequest(_ request: URLRequest, callback: @escaping RequestCallback) {
        pendingRequests.append((request, callback))
    }
    func restartPendingRequests() {
        YouTubeAPIClient.sharedInstance.renewManager()
        for req in pendingRequests {
            YouTubeAPIClient.sharedInstance.manager
                .request(req.0)
                .responseJSON(options: .allowFragments, completionHandler: req.1)
        }
        pendingRequests = []
    }
    open func oauthClientNeedsAuthentication(_ client: NXOAuth2Client!) {}
    open func oauthClientDidGetAccessToken(_ client: NXOAuth2Client!) {}
    open func oauthClient(_ client: NXOAuth2Client!, didFailToGetAccessTokenWithError error: Error!) {
        restartPendingRequests()
    }
    open func oauthClientDidLoseAccessToken(_ client: NXOAuth2Client!) {
        restartPendingRequests()
    }
    open func oauthClientDidRefreshAccessToken(_ client: NXOAuth2Client!) {
        YouTubeAPIClient.refreshAccount(NXOAuth2Account(accountWith: client.accessToken,
                                                        accountType: YouTubeAPIClient.accountType))
        restartPendingRequests()
    }
}
