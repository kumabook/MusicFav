//
//  FeedlyAPI.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/2/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation

import SwiftyJSON
import FeedlyKit
import OAuthSwift
import Prephirences

open class FeedlyOAuthRequestRetrier: OAuthRequestRetrier {
    public override func refreshed(_ succeeded: Bool) {
        if succeeded {
            CloudAPIClient.credential = oauth.client.credential
            CloudAPIClient.shared.updateAccessToken(oauth.client.credential.oauthToken)
        } else {
            CloudAPIClient.credential = nil
            CloudAPIClient.logout()
        }
    }
}


public extension CloudAPIClient {
    fileprivate static let userDefaults = UserDefaults.standard
    fileprivate static var _profile:                    Profile?
    fileprivate static var _notificationDateComponents: DateComponents?
    fileprivate static var _lastChecked:                Date?
    public static var profile: Profile? {
        get {
            if let p = _profile {
                return p
            }
            if let data: NSData = userDefaults.object(forKey: "profile") as? NSData {
                _profile = NSKeyedUnarchiver.unarchiveObject(with: data as Data) as? Profile
                return _profile
            }
            return nil
        }
        set(profile) {
            if let p = profile {
                userDefaults.set(NSKeyedArchiver.archivedData(withRootObject: p), forKey: "profile")
            } else {
                userDefaults.removeObject(forKey: "profile")
            }
            _profile = profile
        }
    }

    static var oauth: OAuth2Swift!
    
    static var credential: OAuthSwiftCredential? {
        get {
            return KeychainPreferences.sharedInstance[CloudAPIClient.keyChainGroup] as? OAuthSwiftCredential
        }
        set {
            KeychainPreferences.sharedInstance[CloudAPIClient.keyChainGroup] = newValue
        }
    }

    public static var isExpired: Bool {
        return credential?.isTokenExpired() ?? true
    }

    static func authorize(_ viewController: UIViewController, callback: (() -> ())? = nil) {
        let vc = OAuthViewController()
        viewController.addChildViewController(vc)
        oauth.authorizeURLHandler = vc
        let _ = oauth.authorize(
            withCallbackURL: URL(string: CloudAPIClient.redirectUrl)!,
            scope: CloudAPIClient.scope.joined(separator: ","),
            state: "Feedly",
            success: { credential, response, parameters in
                CloudAPIClient.credential = credential
                CloudAPIClient.shared.updateAccessToken(credential.oauthToken)
                let _ = CloudAPIClient.shared.fetchProfile().on(
                    failed: { error in
                        if let callback = callback { callback() }
                }, value: { profile in
                    CloudAPIClient.login(profile: profile, token: credential.oauthToken)
                    AppDelegate.shared.reload()
                    if let callback = callback { callback() }
                }).start()
        },
            failure: { error in
                if let callback = callback {
                    callback()
                }
        })
    }


    public static var notificationDateComponents: DateComponents? {
        get {
            if let components = _notificationDateComponents {
                return components
            }
            if let data: Data = userDefaults.object(forKey: "notification_date_components") as? Data {
                return NSKeyedUnarchiver.unarchiveObject(with: data as Data) as? DateComponents
            }
            return nil
        }
        set(notificationDateComponents) {
            if let components = notificationDateComponents {
                userDefaults.set(NSKeyedArchiver.archivedData(withRootObject: components), forKey: "notification_date_components")
            } else {
                userDefaults.removeObject(forKey: "notification_date_components")
            }
            _notificationDateComponents = notificationDateComponents
        }
    }
    
    public static var lastChecked: Date? {
        get {
            if let time = _lastChecked {
                return time as Date
            }
            if let data: Data = userDefaults.object(forKey: "last_checked") as? Data {
                return NSKeyedUnarchiver.unarchiveObject(with: data) as? Date
            }
            return nil
        }
        set(lastChecked) {
            if let date = lastChecked {
                userDefaults.set(NSKeyedArchiver.archivedData(withRootObject: date), forKey: "last_checked")
            } else {
                userDefaults.removeObject(forKey: "last_checked")
            }
            _lastChecked = lastChecked
        }
    }

    fileprivate static func clearAllAccount() {
        credential = nil
        logout()
    }
    
    fileprivate static func loadConfig() {
        let bundle = Bundle.main
        if let path = bundle.path(forResource: "feedly", ofType: "json") {
            let data     = NSData(contentsOfFile: path)
            let jsonObject: AnyObject? = try! JSONSerialization.jsonObject(with: data! as Data,
                options: JSONSerialization.ReadingOptions.mutableContainers) as AnyObject?
            if let obj: AnyObject = jsonObject {
                let json = JSON(obj)
                if json["target"].stringValue == "production" {
                    CloudAPIClient.shared = CloudAPIClient(target: .production)
                } else {
                    CloudAPIClient.shared = CloudAPIClient(target: .sandbox)
                }
                if let clientId = json["client_id"].string {
                    CloudAPIClient.clientId = clientId
                }
                if let clientSecret = json["client_secret"].string {
                    CloudAPIClient.clientSecret = clientSecret
                }
            }
        }
    }

    public static func setup() {
        loadConfig()
        oauth = OAuth2Swift(
            consumerKey:    clientId,
            consumerSecret: clientSecret,
            authorizeUrl:   shared.authUrl,
            accessTokenUrl: shared.tokenUrl,
            responseType:   "code"
        )
        if let c = credential {
            oauth.client.credential.oauthToken          = c.oauthToken
            oauth.client.credential.oauthTokenSecret    = c.oauthTokenSecret
            oauth.client.credential.oauthTokenExpiresAt = c.oauthTokenExpiresAt
            oauth.client.credential.oauthRefreshToken   = c.oauthRefreshToken
        }
        if let p = profile, let c = credential {
            CloudAPIClient.login(profile: p, token: c.oauthToken)
        }
        shared.manager.retrier = FeedlyOAuthRequestRetrier(oauth)
        CloudAPIClient.sharedPipe.0.observeResult({ result in
            guard let event = result.value else { return }
            switch event {
            case .Login(let profile):
                self.profile = profile
            case .Logout:
                self.profile = nil
                self.credential = nil
            }
        })
    }
}
