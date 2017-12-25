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

open class OAuth2ClientDelegate: NSObject, NXOAuth2ClientDelegate {
    public typealias RequestCallback = (DataResponse<Any>) -> Void
    open var pendingRequests: [(APIClient.Router, RequestCallback)]
    public override init() {
        pendingRequests = []
    }
    func addPendingRequest(_ request: APIClient.Router, callback: @escaping RequestCallback) {
        pendingRequests.append((request, callback))
    }
    func restartPendingRequests() {
        for req in pendingRequests {
            APIClient.sharedInstance.manager.request(req.0).responseJSON(options: .allowFragments, completionHandler: req.1)
        }
        pendingRequests = []
    }
    open func oauthClientNeedsAuthentication(_ client: NXOAuth2Client!) {}
    open func oauthClientDidGetAccessToken(_ client: NXOAuth2Client!) {}
    open func oauthClient(_ client: NXOAuth2Client!, didFailToGetAccessTokenWithError error: Error!) {
        restartPendingRequests()
    }
    open func oauthClientDidLoseAccessToken(_ client: NXOAuth2Client!) {}
    open func oauthClientDidRefreshAccessToken(_ client: NXOAuth2Client!) {
        APIClient.refreshAccount(NXOAuth2Account(accountWith: client.accessToken,
                                                 accountType: APIClient.accountType))
        restartPendingRequests()
    }
}

extension APIClient {
    public static var clientSecret   = ""
    public static var baseUrl        = "https://api.soundcloud.com"
    public static var authUrl        = "https://soundcloud.com/connect"
    public static var tokenUrl       = "\(baseUrl)/oauth2/token"
    public static var scope          = Set([] as [String])
    public static var redirectUrl    = "http://localhost/"
    public static var accountType    = "SoundCloud"
    public static var keyChainGroup  = "SoundCloud"

    static let errorResponseKey = "com.alamofire.serialization.response.error.response"

    fileprivate static let userDefaults = UserDefaults.standard
    static func newManager() -> SessionManager {
        let m = Alamofire.SessionManager()
        if let token = APIClient.accessToken {
            m.session.configuration.httpAdditionalHeaders = ["Authorization": "Bearer \(token)"]
        }
        return m
    }

    static var oauth2clientDelegate: OAuth2ClientDelegate!
    static func createOauth2client(_ delegate: OAuth2ClientDelegate) -> NXOAuth2Client? {
        if let accessToken = account?.accessToken {
            return NXOAuth2Client(clientID: clientId,
                              clientSecret: clientSecret,
                              authorizeURL: URL(string: authUrl)!,
                                  tokenURL: URL(string: tokenUrl)!,
                               accessToken: accessToken,
                             keyChainGroup: keyChainGroup,
                                persistent: true,
                                  delegate: delegate)
        } else {
            return nil
        }
    }

    fileprivate static var _account: NXOAuth2Account?
    public static var account: NXOAuth2Account? {
        if let a = _account {
            return a
        }
        let store = NXOAuth2AccountStore.sharedStore() as! NXOAuth2AccountStore
        for account in store.accounts as! [NXOAuth2Account] {
            if account.accountType == APIClient.keyChainGroup {
                _account = account
                return account
            }
        }
        return nil
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
        let store = NXOAuth2AccountStore.sharedStore() as! NXOAuth2AccountStore
        for account in store.accounts as! [NXOAuth2Account] {
            if account.accountType == APIClient.keyChainGroup {
                store.removeAccount(account)
            }
        }
        _account = nil
        SoundCloudKit.APIClient.accessToken = nil
    }

    static func refreshAccount(_ account: NXOAuth2Account) {
        clearAllAccount()
        let store = NXOAuth2AccountStore.sharedStore() as! NXOAuth2AccountStore
        store.addAccount(account)
        SoundCloudKit.APIClient.accessToken = account.accessToken.accessToken
    }

    public class func setup() {
        APIClient.oauth2clientDelegate = OAuth2ClientDelegate()
        loadConfig()
        if let _ = SoundCloudKit.APIClient.me {
            SoundCloudKit.APIClient.accessToken = account?.accessToken.accessToken
        } else {
            SoundCloudKit.APIClient.clearAllAccount()
        }
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
        if let dic = e.userInfo as NSDictionary? {
            if let response:HTTPURLResponse = dic[errorResponseKey] as? HTTPURLResponse {
                if response.statusCode == 401 {
                    if isLoggedIn { clearAllAccount() }
                }
            }
        }
    }


    func fetch(_ route: Router, callback: @escaping OAuth2ClientDelegate.RequestCallback) {
        self.manager.request(route).validate(statusCode: 200..<300).responseJSON(options: .allowFragments) {(response: DataResponse<Any>) -> Void in
            if response.result.isFailure {
                if let oauth2client = APIClient.createOauth2client(APIClient.oauth2clientDelegate) {
                    APIClient.oauth2clientDelegate.addPendingRequest(route, callback: callback)
                    oauth2client.refreshAccessToken()
                    return
                }
            }
            callback(response)
        }
    }

    func fetchItem<T: JSONInitializable>(_ route: Router) -> SignalProducer<T, NSError> {
        return SignalProducer { observer, disposable in
            let callback: OAuth2ClientDelegate.RequestCallback = {(response: DataResponse<Any>) -> Void in
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
            self.fetch(route, callback: callback)
        }
    }

    func fetchItems<T: JSONInitializable>(_ route: Router) -> SignalProducer<[T], NSError> {
        return SignalProducer { observer, disposable in
            let callback: OAuth2ClientDelegate.RequestCallback = {(response: DataResponse<Any
                >) -> Void in
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
            self.fetch(route, callback: callback)
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
