//
//  SoundCloudAPIClient.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/21/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import SoundCloudKit
import SwiftyJSON
import NXOAuth2Client
import ReactiveSwift
import Alamofire
import OAuthSwift
import Prephirences

open class SoundCloudOAuthRequestRetrier: OAuthRequestRetrier {
    public override func refreshed(_ succeeded: Bool) {
        if succeeded {
            APIClient.credential = oauth.client.credential
            APIClient.accessToken = oauth.client.credential.oauthToken
        } else {
            APIClient.credential = nil
            APIClient.accessToken = nil
        }
    }
}

extension APIClient {
    public static var clientSecret   = ""
    public static var baseUrl        = "https://api.soundcloud.com"
    public static var authUrl        = "https://soundcloud.com/connect"
    public static var tokenUrl       = "\(baseUrl)/oauth2/token"
    public static var scope          = Set([] as [String])
    public static var redirectUri    = "http://localhost/"
    public static var keyChainGroup  = "SoundCloud"

    static let errorResponseKey = "com.alamofire.serialization.response.error.response"

    fileprivate static let userDefaults = UserDefaults.standard
    static var oauth: OAuth2Swift!

    static var credential: OAuthSwiftCredential? {
        get {
            return KeychainPreferences.sharedInstance[APIClient.keyChainGroup] as? OAuthSwiftCredential
        }
        set {
            KeychainPreferences.sharedInstance[APIClient.keyChainGroup] = newValue
        }
    }

    fileprivate static var _me: User?
    public static var me: User? {
        get {
            if let m = _me { return m }
            if let data: Data = userDefaults.object(forKey: "soundcloud_me") as? Data {
                return try? User(json: JSON(data: data, options: []))
            }
            return nil
        }
        set(me) {
            if let m = me {
                userDefaults.set(try! m.toJSON().rawData(options: []), forKey: "soundcloud_me")
            } else {
                userDefaults.removeObject(forKey: "soundcloud_me")
            }
            _me = me
        }
    }

    public static func clearAllAccount() {
        credential = nil
        SoundCloudKit.APIClient.accessToken = nil
    }

    public class func setup() {
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
            APIClient.sharedInstance.manager.session.configuration.httpAdditionalHeaders = ["Authorization": "Bearer \(c.oauthToken)"]
        }
        APIClient.sharedInstance.manager.retrier = SoundCloudOAuthRequestRetrier(oauth)
        APIClient.accessToken = credential?.oauthToken
    }

    static func authorize(_ viewController: UIViewController, callback: (() -> ())? = nil) {
        let vc = OAuthViewController()
        viewController.addChildViewController(vc)
        oauth.authorizeURLHandler = vc
        let _ = oauth.authorize(
            withCallbackURL: URL(string: APIClient.redirectUri)!,
            scope: APIClient.scope.joined(separator: ","),
            state: "SoundCloud",
            success: { credential, response, parameters in
                APIClient.credential = credential
                APIClient.accessToken = credential.oauthToken
                APIClient.sharedInstance.fetchMe().on(
                    failed: { error in
                        if let callback = callback { callback() }
                }, value: { user in
                    APIClient.me = user
                    AppDelegate.shared.reload()
                    if let callback = callback { callback() }
                }).start()
        },
            failure: { error in
                if let callback = callback { callback() }
        })
    }

    public class func loadConfig() {
        let bundle = Bundle.main
        if let path = bundle.path(forResource: "soundcloud", ofType: "json") {
            let data     = NSData(contentsOfFile: path)
            let jsonObject: AnyObject? = try! JSONSerialization.jsonObject(with: data! as Data,
                options: JSONSerialization.ReadingOptions.mutableContainers) as AnyObject?
            if let obj: AnyObject = jsonObject {
                let json = JSON(obj)
                if let clientId = json["client_id"].string {
                    APIClient.clientId = clientId
                }
                if let clientSecret = json["client_secret"].string {
                    APIClient.clientSecret = clientSecret
                }
            }
        }
    }

    public class func handleError(_ error: Error) {
        let e = error as NSError
        if let response:HTTPURLResponse = e.userInfo[errorResponseKey] as? HTTPURLResponse {
            if response.statusCode == 401 {
                if isLoggedIn { clearAllAccount() }
            }
        }
    }


    func fetchItem<T: JSONInitializable>(_ route: Router) -> SignalProducer<T, NSError> {
        return SignalProducer { observer, disposable in
            let req = self.manager.request(route).validate(statusCode: 200..<300).responseJSON(options: .allowFragments) {(response: DataResponse<Any>) -> Void in
                if let e = response.result.error as NSError? {
                    if let r = response.response {
                        observer.send(error: NSError(domain: e.domain, code: e.code, userInfo: [APIClient.errorResponseKey:r]))
                    } else {
                        observer.send(error: e)
                    }
                } else if let obj = response.result.value {
                    observer.send(value: T(json: JSON(obj)))
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded {
                req.cancel()
            }
        }
    }

    func fetchItems<T: JSONInitializable>(_ route: Router) -> SignalProducer<[T], NSError> {
        return SignalProducer { observer, disposable in
            let req = self.manager.request(route).validate(statusCode: 200..<300).responseJSON(options: .allowFragments) {(response: DataResponse<Any>) -> Void in
                if let e = response.result.error as NSError? {
                    if let r = response.response {
                        observer.send(error: NSError(domain: e.domain, code: e.code, userInfo: [APIClient.errorResponseKey:r]))
                    } else {
                        observer.send(error: e)
                    }
                } else if let obj = response.result.value {
                    observer.send(value: JSON(obj).arrayValue.map { T(json: $0) })
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded {
                req.cancel()
            }
        }
    }

    func fetchUsers(_ query: String) -> SignalProducer<[User], NSError> {
        return fetchItems(Router.users(query))
    }

    func fetchMe() -> SignalProducer<User, NSError> {
        return fetchItem(Router.me)
    }

    func fetchUser(_ userId: String) -> SignalProducer<User, NSError> {
        return fetchItem(Router.user(userId))
    }

    func fetchTrack(_ trackId: String) -> SignalProducer<Track, NSError> {
        return fetchItem(Router.track(trackId))
    }

    func fetchTracksOf(_ user: User) -> SignalProducer<[Track], NSError> {
        return fetchItems(Router.tracksOfUser(user))
    }

    func fetchPlaylistsOf(_ user: User) -> SignalProducer<[Playlist], NSError> {
        return fetchItems(Router.playlistsOfUser(user))
    }

    func fetchFollowingsOf(_ user: User) -> SignalProducer<[User], NSError> {
        return self.fetchItems(Router.followingsOfUser(user))
    }

    func fetchFavoritesOf(_ user: User) -> SignalProducer<[Track], NSError> {
        return self.fetchItems(Router.favoritesOfUser(user))
    }

    func fetchActivities() -> SignalProducer<ActivityList, NSError> {
        return self.fetchItem(Router.activities)
    }

    func fetchNextActivities(_ nextHref: String) -> SignalProducer<ActivityList, NSError> {
        return self.fetchItem(Router.nextActivities(nextHref))
    }

    func fetchLatestActivities(_ futureHref: String) -> SignalProducer<ActivityList, NSError> {
        return self.fetchItem(Router.futureActivities(futureHref))
    }

    func fetchPlaylist(_ id: Int) -> SignalProducer<Playlist, NSError> {
        return self.fetchItem(Router.playlist("\(id)"))
    }
}
