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
import MusicFeeder

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
            disposable.observeEnded {
                operation.cancel()
            }
            return
        }
    }
}

extension XCDYouTubeVideo: YouTubeVideo {
}

open class YouTubeAPIClient: MusicFeeder.YouTubeAPIClient {
    public func fetchVideo(_ identifier: String) -> SignalProducer<YouTubeVideo, NSError> {
        return XCDYouTubeClient().fetchVideo(identifier).map {
            $0 as YouTubeVideo
        }
    }
    static var sharedInstance = YouTubeAPIClient()
    static var clientId       = ""
    static var clientSecret   = ""
    static var baseUrl        = "https://accounts.google.com"
    static var authUrl        = "\(baseUrl)/o/oauth2/auth"
    static var tokenUrl       = "\(baseUrl)/o/oauth2/token"
    static var scope          = Set(["https://gdata.youtube.com"])
    static var redirectUri    = ""
    static var accountType    = "YouTube"
    static var keyChainGroup  = "YouTube"
    static var API_KEY        = ""
    var API_KEY: String { return YouTubeAPIClient.API_KEY }

    var manager: Alamofire.SessionManager = Alamofire.SessionManager()

    static var credential: OAuthSwiftCredential? {
        get {
            return KeychainPreferences.sharedInstance[YouTubeAPIClient.keyChainGroup] as? OAuthSwiftCredential
        }
        set {
            KeychainPreferences.sharedInstance[YouTubeAPIClient.keyChainGroup] = newValue
        }
    }

    static var isLoggedIn: Bool {
        return credential != nil
    }

    static func refreshAccount(_ credential: OAuthSwiftCredential) {
        clearAllAccount()
        self.credential = credential
    }

    static func clearAllAccount() {
        credential = nil
    }

    static var accessToken: String? {
        return credential?.oauthToken
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
                if let uri = json["redirect_uri"].string {
                    redirectUri = uri
                }
            }
        }
    }

    open static func setup() {
        loadConfig()
        sharedInstance.renewManager()
    }

    static var oauthswift: OAuth2Swift {
        return OAuth2Swift(
            consumerKey:    clientId,
            consumerSecret: clientSecret,
            authorizeUrl:   authUrl,
            responseType:   "code token"
        )
    }

    static func authorize(_ viewController: UIViewController, callback: (() -> ())? = nil) {
        oauthswift.authorizeURLHandler = SafariURLHandler(viewController: viewController, oauthSwift: oauthswift)
        oauthswift.authorize(
            withCallbackURL: URL(string: YouTubeAPIClient.redirectUri)!,
            scope: YouTubeAPIClient.scope.joined(separator: ","),
            state: "YouTube",
            success: { credential, response, parameters in
                YouTubeAPIClient.credential = credential
                if let callback = callback {
                    callback()
                }
        },
            failure: { error in
                print(error.localizedDescription)
                if let callback = callback {
                    callback()
                }
        })
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
                if let t = YouTubeAPIClient.credential?.oauthRefreshToken {
                    YouTubeAPIClient.oauthswift.renewAccessToken(withRefreshToken: t, success: { (credential, res, params) in
                        YouTubeAPIClient.credential = credential
                        let _ = self.request(url, method: method, parameters: parameters, encoding: encoding, callback: callback)
                    }, failure: { (error) in
                        callback(response)
                    })
                } else {
                    callback(response)
                }
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
            disposable.observeEnded {
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
            disposable.observeEnded {
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
            disposable.observeEnded {
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

