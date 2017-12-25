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
    fileprivate static let userDefaults = UserDefaults.standard
    fileprivate static var oauth2clientDelegate = FeedlyOAuth2ClientDelegate()
    fileprivate static var _account:                    NXOAuth2Account?
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
            return NSDate().compare(expiresAt) != ComparisonResult.orderedAscending
        }
        return false
    }

    public static func refreshAccessToken(_ account: NXOAuth2Account) {
        typealias C = CloudAPIClient
        let oauth2client = NXOAuth2Client(clientID: C.clientId,
                                      clientSecret: C.clientSecret,
                                      authorizeURL: NSURL(string: C.shared.authUrl)! as URL!,
                                          tokenURL: NSURL(string: C.shared.tokenUrl)! as URL!,
                                       accessToken: account.accessToken,
                                     keyChainGroup: C.keyChainGroup,
                                        persistent: true,
                                          delegate: CloudAPIClient.oauth2clientDelegate)
        oauth2client?.refreshAccessToken()
    }

    static func refreshAccount(_ account: NXOAuth2Account) {
        clearAllAccount()
        let store = NXOAuth2AccountStore.sharedStore() as! NXOAuth2AccountStore
        store.addAccount(account)
        if let p = profile, let token = account.accessToken.accessToken {
            CloudAPIClient.login(profile: p, token: token)
        }
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
        if let p = profile, let a = account, let token = a.accessToken.accessToken {
            CloudAPIClient.login(profile: p, token: token)
            if isExpired {
                refreshAccessToken(a)
            }
        } else {
            profile = nil
            clearAllAccount()
        }
        CloudAPIClient.sharedPipe.0.observeResult({ result in
            guard let event = result.value else { return }
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

open class FeedlyOAuth2ClientDelegate: NSObject, NXOAuth2ClientDelegate {
    public override init() {
    }
    open func oauthClientNeedsAuthentication(_ client: NXOAuth2Client!) {}
    open func oauthClientDidGetAccessToken(_ client: NXOAuth2Client!) {}
    open func oauthClient(_ client: NXOAuth2Client!, didFailToGetAccessTokenWithError error: Error!) {
    }
    open func oauthClientDidLoseAccessToken(_ client: NXOAuth2Client!) {
    }
    open func oauthClientDidRefreshAccessToken(_ client: NXOAuth2Client!) {
        CloudAPIClient.refreshAccount(NXOAuth2Account(accountWith: client.accessToken,
            accountType: CloudAPIClient.accountType))
    }
}
