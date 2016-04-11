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
import NXOAuth2Client

public extension CloudAPIClient {
    private static let userDefaults = NSUserDefaults.standardUserDefaults()
    private static var oauth2clientDelegate = FeedlyOAuth2ClientDelegate()
    private static var _account:                    NXOAuth2Account?
    private static var _profile:                    Profile?
    private static var _notificationDateComponents: NSDateComponents?
    private static var _lastChecked:                NSDate?
    public static var profile: Profile? {
        get {
            if let p = _profile {
                return p
            }
            if let data: NSData = userDefaults.objectForKey("profile") as? NSData {
                _profile = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? Profile
                return _profile
            }
            return nil
        }
        set(profile) {
            if let p = profile {
                userDefaults.setObject(NSKeyedArchiver.archivedDataWithRootObject(p), forKey: "profile")
            } else {
                userDefaults.removeObjectForKey("profile")
            }
            _profile = profile
        }
    }
    
    public static var account: NXOAuth2Account? {
        get {
            if let a = _account {
                return a
            }
            let store = NXOAuth2AccountStore.sharedStore() as! NXOAuth2AccountStore
            for account in store.accounts as! [NXOAuth2Account] {
                if account.accountType == "Feedly" {
                    _account = account
                    return account
                }
            }
            return nil
        }
    }

    public static var isExpired: Bool {
        if let expiresAt = account?.accessToken.expiresAt {
            return NSDate().compare(expiresAt) != NSComparisonResult.OrderedAscending
        }
        return false
    }

    public static func refreshAccessToken(account: NXOAuth2Account) {
        typealias C = CloudAPIClient
        let oauth2client = NXOAuth2Client(clientID: C.clientId,
                                      clientSecret: C.clientSecret,
                                      authorizeURL: NSURL(string: C.sharedInstance.authUrl)!,
                                          tokenURL: NSURL(string: C.sharedInstance.tokenUrl)!,
                                       accessToken: account.accessToken,
                                     keyChainGroup: C.keyChainGroup,
                                        persistent: true,
                                          delegate: CloudAPIClient.oauth2clientDelegate)
        oauth2client.refreshAccessToken()
    }

    static func refreshAccount(account: NXOAuth2Account) {
        clearAllAccount()
        let store = NXOAuth2AccountStore.sharedStore() as! NXOAuth2AccountStore
        store.addAccount(account)
        if let p = profile, token = account.accessToken.accessToken {
            CloudAPIClient.login(p, token: token)
        }
    }

    public static var notificationDateComponents: NSDateComponents? {
        get {
            if let components = _notificationDateComponents {
                return components
            }
            if let data: NSData = userDefaults.objectForKey("notification_date_components") as? NSData {
                return NSKeyedUnarchiver.unarchiveObjectWithData(data) as? NSDateComponents
            }
            return nil
        }
        set(notificationDateComponents) {
            if let components = notificationDateComponents {
                userDefaults.setObject(NSKeyedArchiver.archivedDataWithRootObject(components), forKey: "notification_date_components")
            } else {
                userDefaults.removeObjectForKey("notification_date_components")
            }
            _notificationDateComponents = notificationDateComponents
        }
    }
    
    public static var lastChecked: NSDate? {
        get {
            if let time = _lastChecked {
                return time
            }
            if let data: NSData = userDefaults.objectForKey("last_checked") as? NSData {
                return NSKeyedUnarchiver.unarchiveObjectWithData(data) as? NSDate
            }
            return nil
        }
        set(lastChecked) {
            if let date = lastChecked {
                userDefaults.setObject(NSKeyedArchiver.archivedDataWithRootObject(date), forKey: "last_checked")
            } else {
                userDefaults.removeObjectForKey("last_checked")
            }
            _lastChecked = lastChecked
        }
    }

    private static func clearAllAccount() {
        guard let store    = NXOAuth2AccountStore.sharedStore() as? NXOAuth2AccountStore else { return }
        guard let accounts = store.accounts as? [NXOAuth2Account]                        else { return }
        for account in accounts {
            if account.accountType == "Feedly" {
                store.removeAccount(account)
            }
        }
        _account = nil
        profile = nil
    }
    
    private static func loadConfig() {
        let bundle = NSBundle.mainBundle()
        if let path = bundle.pathForResource("feedly", ofType: "json") {
            let data     = NSData(contentsOfFile: path)
            let jsonObject: AnyObject? = try? NSJSONSerialization.JSONObjectWithData(data!,
                options: NSJSONReadingOptions.MutableContainers)
            if let obj: AnyObject = jsonObject {
                let json = JSON(obj)
                if json["target"].stringValue == "production" {
                    CloudAPIClient.sharedInstance = CloudAPIClient(target: .Production)
                } else {
                    CloudAPIClient.sharedInstance = CloudAPIClient(target: .Sandbox)
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
        if let p = profile, a = account, token = a.accessToken.accessToken {
            CloudAPIClient.login(p, token: token)
            if isExpired {
                refreshAccessToken(a)
            }
        } else {
            profile = nil
            clearAllAccount()
        }
        CloudAPIClient.sharedPipe.0.observeNext({ event in
            switch event {
            case .Login(let profile):
                self.profile = profile
            case .Logout:
                if self.isExpired {
                    self.refreshAccessToken(self.account!)
                } else {
                    self.clearAllAccount()
                }
            }
        })
    }
}

public class FeedlyOAuth2ClientDelegate: NSObject, NXOAuth2ClientDelegate {
    public override init() {
    }
    public func oauthClientNeedsAuthentication(client: NXOAuth2Client!) {}
    public func oauthClientDidGetAccessToken(client: NXOAuth2Client!) {}
    public func oauthClient(client: NXOAuth2Client!, didFailToGetAccessTokenWithError error: NSError!) {
    }
    public func oauthClientDidLoseAccessToken(client: NXOAuth2Client!) {
    }
    public func oauthClientDidRefreshAccessToken(client: NXOAuth2Client!) {
        CloudAPIClient.refreshAccount(NXOAuth2Account(accountWithAccessToken: client.accessToken,
            accountType: CloudAPIClient.accountType))
    }
}
