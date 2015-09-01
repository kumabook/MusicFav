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
import ReactiveCocoa
import Box
import Alamofire

public class OAuth2ClientDelegate: NSObject, NXOAuth2ClientDelegate {
    public typealias RequestCallback = (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void
    public var pendingRequests: [(APIClient.Router, RequestCallback)]
    public override init() {
        pendingRequests = []
    }
    func addPendingRequest(request: APIClient.Router, callback: RequestCallback) {
        pendingRequests.append((request, callback))
    }
    func restartPendingRequests() {
        for req in pendingRequests {
            APIClient.sharedInstance.manager.request(req.0).responseJSON(options: .allZeros, completionHandler: req.1)
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
        APIClient.refreshAccount(NXOAuth2Account(accountWithAccessToken: client.accessToken,
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

    private static let userDefaults = NSUserDefaults.standardUserDefaults()
    public static var sharedInstance = APIClient()
    static func newManager() -> Manager {
        var m = Alamofire.Manager()
        if let token = APIClient.accessToken {
            m.session.configuration.HTTPAdditionalHeaders = ["Authorization": "Bearer \(token)"]
        }
        return m
    }

    static var oauth2clientDelegate: OAuth2ClientDelegate!
    static func createOauth2client(delegate: OAuth2ClientDelegate) -> NXOAuth2Client? {
        if let accessToken = account?.accessToken {
            return NXOAuth2Client(clientID: clientId,
                              clientSecret: clientSecret,
                              authorizeURL: NSURL(string: authUrl)!,
                                  tokenURL: NSURL(string: tokenUrl)!,
                               accessToken: accessToken,
                             keyChainGroup: keyChainGroup,
                                persistent: true,
                                  delegate: delegate)
        } else {
            return nil
        }
    }

    private static var _account: NXOAuth2Account?
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

    private static var _me: User?
    public static var me: User? {
        get {
            if let m = _me { return m }
            if let data: NSData = userDefaults.objectForKey("soundcloud_me") as? NSData {
                return User(json: JSON(data: data, options: .allZeros, error: nil))
            }
            return nil
        }
        set(me) {
            if let m = me {
                userDefaults.setObject(m.toJSON().rawData(options: .allZeros, error: nil)!, forKey: "soundcloud_me")
            } else {
                userDefaults.removeObjectForKey("soundcloud_me")
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

    static func refreshAccount(account: NXOAuth2Account) {
        clearAllAccount()
        let store = NXOAuth2AccountStore.sharedStore() as! NXOAuth2AccountStore
        store.addAccount(account)
    }

    public class func setup() {
        APIClient.oauth2clientDelegate = OAuth2ClientDelegate()
        loadConfig()
        SoundCloudKit.APIClient.accessToken = account?.accessToken.accessToken
    }

    public class func loadConfig() {
        let bundle = NSBundle.mainBundle()
        if let path = bundle.pathForResource("soundcloud", ofType: "json") {
            let data     = NSData(contentsOfFile: path)
            let jsonObject: AnyObject? = NSJSONSerialization.JSONObjectWithData(data!,
                options: NSJSONReadingOptions.MutableContainers,
                error: nil)
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

    func fetch(route: Router, callback: OAuth2ClientDelegate.RequestCallback) {
        self.manager.request(route).validate(statusCode: 200..<300).responseJSON(options: .allZeros) {(req: NSURLRequest, res: NSHTTPURLResponse?, obj: AnyObject?, error: NSError?) -> Void in
            if let e = error {
                if let oauth2client = APIClient.createOauth2client(APIClient.oauth2clientDelegate) {
                    APIClient.oauth2clientDelegate.addPendingRequest(route, callback: callback)
                    oauth2client.refreshAccessToken()
                    return
                }
            }
            callback(req, res, obj, error)
        }
    }

    func fetchItem<T: JSONInitializable>(route: Router) -> SignalProducer<T, NSError> {
        return SignalProducer { sink, disposable in
            let callback: OAuth2ClientDelegate.RequestCallback = {(req: NSURLRequest, res: NSHTTPURLResponse?, obj: AnyObject?, error: NSError?) -> Void in
                if let e = error {
                    sink.put(.Error(Box(e)))
                } else {
                    sink.put(.Next(Box(T(json: JSON(obj!)))))
                    sink.put(.Completed)
                }
            }
            self.fetch(route, callback: callback)
        }
    }

    func fetchItems<T: JSONInitializable>(route: Router) -> SignalProducer<[T], NSError> {
        return SignalProducer { sink, disposable in
            let callback: OAuth2ClientDelegate.RequestCallback = {(req: NSURLRequest, res: NSHTTPURLResponse?, obj: AnyObject?, error: NSError?) -> Void in
                if let e = error {
                    sink.put(.Error(Box(e)))
                } else {
                    sink.put(.Next(Box(JSON(obj!).arrayValue.map { T(json: $0) })))
                    sink.put(.Completed)
                }
            }
            self.fetch(route, callback: callback)
        }
    }

    func fetchUsers(query: String) -> SignalProducer<[User], NSError> {
        return fetchItems(Router.Users(query))
    }

    func fetchMe() -> SignalProducer<User, NSError> {
        return fetchItem(Router.Me)
    }

    func fetchUser(userId: String) -> SignalProducer<User, NSError> {
        return fetchItem(Router.User(userId))
    }

    func fetchTrack(trackId: String) -> SignalProducer<Track, NSError> {
        return fetchItem(Router.Track(trackId))
    }

    func fetchTracksOf(user: User) -> SignalProducer<[Track], NSError> {
        return fetchItems(Router.TracksOfUser(user))
    }

    func fetchPlaylistsOf(user: User) -> SignalProducer<[Playlist], NSError> {
        return fetchItems(Router.PlaylistsOfUser(user))
    }

    func fetchFollowingsOf(user: User) -> SignalProducer<[User], NSError> {
        return self.fetchItems(Router.FollowingsOfUser(user))
    }

    func fetchFavoritesOf(user: User) -> SignalProducer<[Track], NSError> {
        return self.fetchItems(Router.FavoritesOfUser(user))
    }

    func fetchActivities() -> SignalProducer<ActivityList, NSError> {
        return self.fetchItem(Router.Activities)
    }

    func fetchNextActivities(nextHref: String) -> SignalProducer<ActivityList, NSError> {
        return self.fetchItem(Router.NextActivities(nextHref))
    }

    func fetchLatestActivities(futureHref: String) -> SignalProducer<ActivityList, NSError> {
        return self.fetchItem(Router.FutureActivities(futureHref))
    }
}