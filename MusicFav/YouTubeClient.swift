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
import MusicFeeder
import OAuthSwift
import Prephirences
import YouTubeKit
import FeedlyKit

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
var StoredPropertyKeyForTrack: UInt8 = 0
extension YouTubeKit.PlaylistItem {
    public var track: Track {
        if let t = objc_getAssociatedObject(self, &StoredPropertyKeyForTrack) as? Track {
            return t
        }
        let t = Track(id: "\(Provider.youTube.rawValue)/\(videoId)",
                provider: Provider.youTube,
                     url: "https://www.youtube.com/watch?v=\(videoId)",
              identifier: videoId,
                   title: title)
        objc_setAssociatedObject(self, &StoredPropertyKeyForTrack, t, .OBJC_ASSOCIATION_RETAIN)
        return t
    }
    func toPlaylist() -> MusicFeeder.Playlist {
        return MusicFeeder.Playlist(id: "youtube-track-\(id)", title: title, tracks: [track])
    }
}

class ChannelStream: FeedlyKit.Stream {
    let channel: Channel
    init(channel: Channel) {
        self.channel = channel
    }
    open override var streamTitle: String { return channel.title }
    open override var streamId:    String { return "feed/https://www.youtube.com/feeds/videos.xml?channel_id=\(channel.id)" }
    open override var thumbnailURL: URL? {
        if let url = channel.thumbnails["default"] { return URL(string: url) }
        else if let url = channel.thumbnails["medium"]  { return URL(string: url) }
        else if let url = channel.thumbnails["high"]    { return URL(string: url) }
        else                                            { return nil }
    }
}

open class YouTubeOAuthRequestRetrier: OAuthRequestRetrier {
    public override func refreshed(_ succeeded: Bool) {
        if succeeded {
            APIClient.credential = oauth.client.credential
            APIClient.shared.accessToken = oauth.client.credential.oauthToken
        } else {
            APIClient.credential = nil
            APIClient.shared.accessToken = nil
        }
    }
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

    static func clearAllAccount() {
        credential = nil
        APIClient.shared.accessToken = nil
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
                    YouTubeKit.APIClient.shared.API_KEY = apiKey
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
        oauth = OAuth2Swift(
            consumerKey:    clientId,
            consumerSecret: clientSecret,
            authorizeUrl:   authUrl,
            accessTokenUrl: tokenUrl,
            responseType:   "code"
        )
        if let c = credential {
            oauth.client.credential.oauthToken          = c.oauthToken
            oauth.client.credential.oauthTokenSecret    = c.oauthTokenSecret
            oauth.client.credential.oauthTokenExpiresAt = c.oauthTokenExpiresAt
            oauth.client.credential.oauthRefreshToken   = c.oauthRefreshToken
        }
        YouTubeKit.APIClient.shared.accessToken     = credential?.oauthToken
        YouTubeKit.APIClient.shared.manager.retrier = YouTubeOAuthRequestRetrier(oauth)
    }

    static var oauth: OAuth2Swift!

    static func authorize(_ viewController: UIViewController, callback: (() -> ())? = nil) {
        oauth.authorizeURLHandler = SafariURLHandler(viewController: viewController, oauthSwift: oauth)
        let _ = oauth.authorize(
            withCallbackURL: URL(string: YouTubeAPIClient.redirectUri)!,
            scope: YouTubeAPIClient.scope.joined(separator: ","),
            state: "YouTube",
            success: { credential, response, parameters in
                YouTubeAPIClient.credential = credential
                APIClient.shared.accessToken = credential.oauthToken
                AppDelegate.shared.reload()
                if let callback = callback {
                    callback()
                }
        },
            failure: { error in
                if let callback = callback {
                    callback()
                }
        })
    }
}

extension YouTubeKit.APIClient {
    func fetchGuideCategories(regionCode: String, pageToken: String?) -> SignalProducer<PaginatedResponse<GuideCategory>, NSError> {
        return SignalProducer<PaginatedResponse<GuideCategory>, NSError> { observer , disposable in
            let req = self.fetchGuideCategories(regionCode: regionCode, pageToken: pageToken) { response in
                if let e = response.result.error as NSError? {
                    observer.send(error: e)
                } else if let value = response.result.value {
                    observer.send(value: value)
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded {
                req.cancel()
            }
        }
    }
    func fetchMyChannels(_ pageToken: String?) -> SignalProducer<PaginatedResponse<MyChannel>, NSError> {
        return SignalProducer<PaginatedResponse<MyChannel>, NSError> { observer , disposable in
            let req = self.fetchMyChannels(pageToken: pageToken) { response in
                if let e = response.result.error as NSError? {
                    observer.send(error: e)
                } else if let value = response.result.value {
                    observer.send(value: value)
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded {
                req.cancel()
            }
        }
    }
    func fetchChannels(of category: GuideCategory, pageToken: String?) -> SignalProducer<PaginatedResponse<Channel>, NSError> {
        return SignalProducer<PaginatedResponse<Channel>, NSError> { observer , disposable in
            let req = self.fetchChannels(of: category, pageToken: pageToken) { response in
                if let e = response.result.error as NSError? {
                    observer.send(error: e)
                } else if let value = response.result.value {
                    observer.send(value: value)
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded {
                req.cancel()
            }
        }
    }
    func fetchSubscriptions(_ pageToken: String?) -> SignalProducer<PaginatedResponse<YouTubeKit.Subscription>, NSError> {
        return SignalProducer<PaginatedResponse<YouTubeKit.Subscription>, NSError> { observer , disposable in
            let req = self.fetchSubscriptions(pageToken: pageToken) { response in
                if let e = response.result.error as NSError? {
                    observer.send(error: e)
                } else if let value = response.result.value {
                    observer.send(value: value)
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded {
                req.cancel()
            }
        }
    }

    func searchChannel(by query: String?, pageToken: String?) -> SignalProducer<PaginatedResponse<Channel>, NSError> {
        return SignalProducer<PaginatedResponse<Channel>, NSError> { observer , disposable in
            let req = self.searchChannel(by: query, pageToken: pageToken) { response in
                if let e = response.result.error as NSError? {
                    observer.send(error: e)
                } else if let value = response.result.value {
                    observer.send(value: value)
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded {
                req.cancel()
            }
        }
    }
    func fetchMyPlaylists(pageToken: String?) -> SignalProducer<PaginatedResponse<YouTubeKit.Playlist>, NSError> {
        return SignalProducer<PaginatedResponse<YouTubeKit.Playlist>, NSError> { observer , disposable in
            let req = self.fetchMyPlaylists(pageToken: pageToken) { response in
                if let e = response.result.error as NSError? {
                    observer.send(error: e)
                } else if let value = response.result.value {
                    observer.send(value: value)
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded {
                req.cancel()
            }
        }
    }
    func fetchPlaylistItems(_ id: String, pageToken: String?) -> SignalProducer<PaginatedResponse<YouTubeKit.PlaylistItem>, NSError> {
        return SignalProducer<PaginatedResponse<YouTubeKit.PlaylistItem>, NSError> { observer , disposable in
            let req = self.fetchPlaylistItems(id, pageToken: pageToken) { response in
                if let e = response.result.error as NSError? {
                    observer.send(error: e)
                } else if let value = response.result.value {
                    observer.send(value: value)
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded {
                req.cancel()
            }
        }
    }
    func fetchPlaylistItems(of playlist: YouTubeKit.Playlist, pageToken: String?) -> SignalProducer<PaginatedResponse<YouTubeKit.PlaylistItem>, NSError> {
        return SignalProducer<PaginatedResponse<YouTubeKit.PlaylistItem>, NSError> { observer , disposable in
            let req = self.fetchPlaylistItems(of: playlist, pageToken: pageToken) { response in
                if let e = response.result.error as NSError? {
                    observer.send(error: e)
                } else if let value = response.result.value {
                    observer.send(value: value)
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded {
                req.cancel()
            }
        }
    }
}

