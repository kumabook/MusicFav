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

struct FeedlyAPIClientConfig {
    static let baseUrl      = "https://sandbox.feedly.com"
    static let authPath     = "/v3/auth/auth"
    static let tokenPath    = "/v3/auth/token"
    static let accountType  = "Feedly"
    static let clientId     = "sandbox"
    static let clientSecret = "8LDQOW8KPYFPCQV2UL6J"
    static let redirectUrl  = "http://localhost"
    static let scopeUrl     = "https://cloud.feedly.com/subscriptions"
    static let authUrl      = String(format: "%@/%@", baseUrl, authPath)
    static let tokenUrl     = String(format: "%@/%@", baseUrl, tokenPath)
    static let perPage      = 15
}

class FeedlyAPIClient {
    class var sharedInstance : FeedlyAPIClient {
        struct Static {
            static let instance : FeedlyAPIClient = FeedlyAPIClient()
        }
        return Static.instance
    }

    private var _account: NXOAuth2Account?
    private let userDefaults = NSUserDefaults.standardUserDefaults()
    var isLoggedIn: Bool {
        return account != nil
    }

    var account: NXOAuth2Account? {
        get {
            if let a = _account {
                return a
            }
            let store = NXOAuth2AccountStore.sharedStore() as NXOAuth2AccountStore
            for account in store.accounts as [NXOAuth2Account] {
                if account.accountType == "Feedly" {
                    _account = account
                    return account
                }
            }
            return nil
        }
    }
    var _profile: Profile?
    var profile: Profile? {
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
    
    func clearAllAccount() {
        let store = NXOAuth2AccountStore.sharedStore() as NXOAuth2AccountStore
        for account in store.accounts as [NXOAuth2Account] {
            if account.accountType == "Feedly" {
                _account = account
                store.removeAccount(account)
            }
        }
    }
    
    func fetchProfile() -> ColdSignal<Profile> {
        return ColdSignal { (sink, disposable) in
            let client = FeedlyKit.CloudAPIClient()
            client.fetchProfile({ (req, res, profile, error) -> Void in
                if let e = error {
                    sink.put(.Error(e))
                } else {
                    sink.put(Event.Next(Box(profile!)))
                    sink.put(.Completed)
                }
            })
        }
    }
    
    func fetchSubscriptions() -> ColdSignal<[Subscription]> {
        return ColdSignal { (sink, disposable) in
            let client = FeedlyKit.CloudAPIClient()
            client.fetchSubscriptions({ (req, res, subscriptions, error) -> Void in
                if let e = error {
                    sink.put(.Error(e))
                } else {
                    sink.put(.Next(Box(subscriptions!)))
                    sink.put(.Completed)
                }
            })
        }
    }

    func fetchEntries(#streamId: String, newerThan: Int64) -> ColdSignal<PaginatedEntryCollection> {
        var params = [
                "count": String(FeedlyAPIClientConfig.perPage),
            "newerThan": String(newerThan)
        ]
        return fetchEntries(streamId: streamId, params: params)
    }

    func fetchEntries(#streamId: String, continuation: String?) -> ColdSignal<PaginatedEntryCollection> {
        var params = [
            "count": String(FeedlyAPIClientConfig.perPage)
        ]
        if let c = continuation {
            params["continuation"] = c
        }
        return fetchEntries(streamId: streamId, params: params)
    }
    func fetchAllEntries(#newerThan: Int64) -> ColdSignal<PaginatedEntryCollection> {
        var params = [
            "count": String(FeedlyAPIClientConfig.perPage),
            "newerThan": String(newerThan)
        ]
        if let userId = profile?.id {
            return fetchEntries(streamId: "user/\(userId)/category/global.all", params: params)
        } else {
            return fetchEntries(streamId: "topic/music", params: params)
        }
    }

    func fetchAllEntries(#continuation: String?) -> ColdSignal<PaginatedEntryCollection> {
        
        var params = [
            "count": String(FeedlyAPIClientConfig.perPage)
        ]
        if let c = continuation {
            params["continuation"] = c
        }
        if let userId = profile?.id {
            return fetchEntries(streamId: "user/\(userId)/category/global.all", params: params)
        } else {
            return fetchEntries(streamId: "topic/music", params: params)
        }
    }
    

    func fetchEntries(#streamId: String, params: AnyObject) -> ColdSignal<PaginatedEntryCollection> {
        return ColdSignal { (sink, disposable) in
            let client = FeedlyKit.CloudAPIClient()
            var paginationParams = PaginationParams()
            
            client.fetchContents(streamId, paginationParams:paginationParams, completionHandler: { (req, res, entries, error) -> Void in
                if let e = error {
                    sink.put(.Error(e))
                } else {
                    sink.put(.Next(Box(entries!)))
                    sink.put(.Completed)
                }
            })
        }
    }
    
    func fetchFeedsByIds(feedIds: [String]) -> ColdSignal<[Feed]> {
        return ColdSignal { (sink, disposable) in
            let client = FeedlyKit.CloudAPIClient()
            var paginationParams = PaginationParams()
            client.fetchFeeds(feedIds, completionHandler: { (req, res, feeds, error) -> Void in
                if let e = error {
                    sink.put(.Error(e))
                } else {
                    print(feeds)
                    sink.put(.Next(Box(feeds!)))
                    sink.put(.Completed)
                }
            })
        }
    }

    
    func fetchFeedsByTopic(topic: String) -> ColdSignal<[Feed]> {
        return ColdSignal { (sink, disposable) in
            let manager = AFHTTPRequestOperationManager()
            let url = NSString(format: "%@/v3/search/feeds",
                FeedlyAPIClientConfig.baseUrl)

            manager.requestSerializer.setValue(self.account?.accessToken.accessToken,
                forHTTPHeaderField:"Authorization")
            manager.GET(url, parameters: ["query": "#" + topic],
                success: { (operation:AFHTTPRequestOperation!, response:AnyObject!) -> Void in
                    println(operation.response)
                    println(response)
                    let json = JSON(response)
                    sink.put(.Next(Box(json["results"].array!.map({ Feed(json: $0)}))))
                    sink.put(.Completed)
                    
                },
                failure: { (operation:AFHTTPRequestOperation!, error:NSError!) -> Void in
                    println(error)
                    println(operation.response)
                    sink.put(.Error(error))
            })
        }
    }
}
