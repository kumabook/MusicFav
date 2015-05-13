//
//  FeedlyAPIClient.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/21/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import SwiftyJSON
import ReactiveCocoa
import LlamaKit
import FeedlyKit
import Alamofire
import NXOAuth2Client

struct FeedlyAPI {
    static var perPage      = 15
    static var clientId     = "sandbox"
    static var clientSecret = ""
    static let authPath     = "/v3/auth/auth"
    static let tokenPath    = "/v3/auth/token"
    static let accountType  = "Feedly"
    static let redirectUrl  = "http://localhost"
    static let scopeUrl     = "https://cloud.feedly.com/subscriptions"
    private static let userDefaults = NSUserDefaults.standardUserDefaults()
    private static var _account:          NXOAuth2Account?
    private static var _profile:          Profile?
    private static var _notificationTime: NSDateComponents?
    private static var _lastChecked:      NSDate?
    static var profile: Profile? {
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

    static var account: NXOAuth2Account? {
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

    static var notificationTime: NSDateComponents? {
        get {
            if let time = _notificationTime {
                return time
            }
            if let data: NSData = userDefaults.objectForKey("notification_time") as? NSData {
                return NSKeyedUnarchiver.unarchiveObjectWithData(data) as? NSDateComponents
            }
            return nil
        }
        set(notificationTime) {
            if let time = notificationTime {
                userDefaults.setObject(NSKeyedArchiver.archivedDataWithRootObject(time), forKey: "notification_time")
            } else {
                userDefaults.removeObjectForKey("notification_time")
            }
            _notificationTime = notificationTime
        }
    }

    static var nextNotificationDate: NSDate? {
        if let time = notificationTime {
            let calendar = NSCalendar.currentCalendar()
            var components = calendar.components(NSCalendarUnit.CalendarUnitYear  |
                                                 NSCalendarUnit.CalendarUnitMonth |
                                                 NSCalendarUnit.CalendarUnitDay   |
                                                 NSCalendarUnit.CalendarUnitHour  |
                                                 NSCalendarUnit.CalendarUnitMinute, fromDate: NSDate())
            components.hour   = time.hour
            components.minute = time.minute
            components.second = 0
            if let date = calendar.dateFromComponents(components) {
                if date.timeIntervalSinceNow > 0 {
                    return date
                }
                components.day = components.day + 1
                return calendar.dateFromComponents(components)
            }
        }
        return nil
    }

    static var lastChecked: NSDate? {
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

    static var isLoggedIn: Bool {
        return FeedlyAPI.account != nil
    }

    static func clearAllAccount() {
        let store = NXOAuth2AccountStore.sharedStore() as! NXOAuth2AccountStore
        for account in store.accounts as! [NXOAuth2Account] {
            if account.accountType == "Feedly" {
                store.removeAccount(account)
            }
        }
        _account = nil
    }

    static func loadConfig() {
        let bundle = NSBundle.mainBundle()
        if let path = bundle.pathForResource("feedly", ofType: "json") {
            let data     = NSData(contentsOfFile: path)
            let jsonObject: AnyObject? = NSJSONSerialization.JSONObjectWithData(data!,
                options: NSJSONReadingOptions.MutableContainers,
                error: nil)
            if let obj: AnyObject = jsonObject {
                let json = JSON(obj)
                if json["target"].stringValue == "production" {
                    CloudAPIClient.sharedInstance = CloudAPIClient(target: .Production)
                } else {
                    CloudAPIClient.sharedInstance = CloudAPIClient(target: .Sandbox)
                }
                if let clientId = json["client_id"].string {
                    FeedlyAPI.clientId = clientId
                }
                if let clientSecret = json["client_secret"].string {
                    FeedlyAPI.clientSecret = clientSecret
                }
            }
        }
    }
}

extension CloudAPIClient {
    static var sharedInstance: CloudAPIClient = CloudAPIClient(target: Target.Sandbox)

    class func alertController(#error:NSError, handler: (UIAlertAction!) -> Void) -> UIAlertController {
        let ac = UIAlertController(title: "Network error".localize(),
            message: "Sorry, network error occured.".localize(),
            preferredStyle: UIAlertControllerStyle.Alert)
        let okAction = UIAlertAction(title: "OK".localize(), style: UIAlertActionStyle.Default, handler: handler)
        ac.addAction(okAction)
        return ac
    }

    class func setAccessToken(account: NXOAuth2Account) {
        CloudAPIClient.sharedInstance.setAccessToken(account.accessToken.accessToken)
    }

    var isLoggedIn: Bool {
        return FeedlyAPI.isLoggedIn
    }

    var authUrl:  String {
        let url = String(format: "%@%@", target.baseUrl, FeedlyAPI.authPath)
        return url.stringByReplacingOccurrencesOfString("http",
                                           withString: "https",
                                              options: nil,
                                                range: nil)
    }
    var tokenUrl: String { return String(format: "%@%@", target.baseUrl, FeedlyAPI.tokenPath) }

    func fetchProfile() -> SignalProducer<Profile, NSError> {
        return SignalProducer { (sink, disposable) in
            let req = self.fetchProfile({ (req, res, profile, error) -> Void in
                if let e = error {
                    sink.put(.Error(Box(e)))
                } else {
                    sink.put(Event.Next(Box(profile!)))
                    sink.put(.Completed)
                }
            })
            disposable.addDisposable({ req.cancel() })
        }
    }

    func fetchSubscriptions() -> SignalProducer<[Subscription], NSError> {
        return SignalProducer { (sink, disposable) in
            let req = self.fetchSubscriptions({ (req, res, subscriptions, error) -> Void in
                if let e = error {
                    sink.put(.Error(Box(e)))
                } else {
                    sink.put(.Next(Box(subscriptions!)))
                    sink.put(.Completed)
                }
            })
            disposable.addDisposable({ req.cancel() })
        }
    }

    func fetchEntries(#streamId: String, newerThan: Int64, unreadOnly: Bool) -> SignalProducer<PaginatedEntryCollection, NSError> {
        var paginationParams        = PaginationParams()
        paginationParams.unreadOnly = unreadOnly
        paginationParams.count      = FeedlyAPI.perPage
        paginationParams.newerThan  = newerThan
        return fetchEntries(streamId: streamId, paginationParams: paginationParams)
    }

    func fetchEntries(#streamId: String, continuation: String?, unreadOnly: Bool) -> SignalProducer<PaginatedEntryCollection, NSError> {
        var paginationParams          = PaginationParams()
        paginationParams.unreadOnly   = unreadOnly
        paginationParams.count        = FeedlyAPI.perPage
        paginationParams.continuation = continuation
        return fetchEntries(streamId: streamId, paginationParams: paginationParams)
    }

    func fetchEntries(#streamId: String, paginationParams: PaginationParams) -> SignalProducer<PaginatedEntryCollection, NSError> {
        return SignalProducer { (sink, disposable) in
            let req = self.fetchContents(streamId, paginationParams: paginationParams, completionHandler: { (req, res, entries, error) -> Void in
                if let e = error {
                    sink.put(.Error(Box(e)))
                } else {
                    sink.put(.Next(Box(entries!)))
                    sink.put(.Completed)
                }
            })
            disposable.addDisposable({ req.cancel() })
        }
    }

    func fetchFeedsByIds(feedIds: [String]) -> SignalProducer<[Feed], NSError> {
        return SignalProducer { (sink, disposable) in
            let req = self.fetchFeeds(feedIds, completionHandler: { (req, res, feeds, error) -> Void in
                if let e = error {
                    sink.put(.Error(Box(e)))
                } else {
                    sink.put(.Next(Box(feeds!)))
                    sink.put(.Completed)
                }
            })
            disposable.addDisposable({ req.cancel() })
        }
    }

    func fetchCategories() -> SignalProducer<[FeedlyKit.Category], NSError> {
        return SignalProducer { (sink, disposable) in
            let req = self.fetchCategories({ (req, res, categories, error) -> Void in
                if let e = error {
                    sink.put(.Error(Box(e)))
                } else {
                    sink.put(.Next(Box(categories!)))
                    sink.put(.Completed)
                }
            })
            disposable.addDisposable({ req.cancel() })
        }
    }

    func searchFeeds(query: SearchQueryOfFeed) -> SignalProducer<[Feed], NSError> {
        return SignalProducer { (sink, disposable) in
            let req = self.searchFeeds(query, completionHandler: { (req, res, feedResults, error) -> Void in
                if let e = error {
                    sink.put(.Error(Box(e)))
                } else {
                    if let _feedResults = feedResults {
                        sink.put(.Next(Box(_feedResults.results)))
                        sink.put(.Completed)
                    }
                }
            })
            disposable.addDisposable({ req.cancel() })
        }
    }
}
