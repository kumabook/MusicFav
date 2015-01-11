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

struct FeedlyAPIClientConfig {
    static let baseUrl      = "https://sandbox.feedly.com"
    static let authPath     = "/v3/auth/auth"
    static let tokenPath    = "/v3/auth/token"
    static let accountType  = "Feedly"
    static let clientId     = "sandbox"
    static let clientSecret = "9ZUHFZ9N2ZQ0XM5ERU1Z"
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
            let manager = AFHTTPRequestOperationManager()
            let url = NSString(format: "%@/v3/profile",
                FeedlyAPIClientConfig.baseUrl)
            manager.requestSerializer.setValue(self.account?.accessToken.accessToken,
                forHTTPHeaderField:"Authorization")
            manager.GET(url, parameters: nil,
                success: { (operation:AFHTTPRequestOperation!, response:AnyObject!) -> Void in
                    println(operation.response)
                    println(response)
                    let json = JSON(response)
                    sink.put(.Next(Box(Profile(json: json))))
                    sink.put(.Completed)
                },
                failure: { (operation:AFHTTPRequestOperation!, error:NSError!) -> Void in
                    println(error)
                    println(operation.response)
                    sink.put(.Error(error))
            })
            disposable.addDisposable {
                manager.operationQueue.cancelAllOperations()
            }
        }
    }
    
    func fetchSubscriptions() -> ColdSignal<[Subscription]> {
        return ColdSignal { (sink, disposable) in
            let manager = AFHTTPRequestOperationManager()
            let url = NSString(format: "%@/v3/subscriptions",
                FeedlyAPIClientConfig.baseUrl)
            manager.requestSerializer.setValue(self.account?.accessToken.accessToken,
                forHTTPHeaderField:"Authorization")
            manager.GET(url, parameters: nil,
                success: { (operation:AFHTTPRequestOperation!, response:AnyObject!) -> Void in
                    println(operation.response)
                    println(response)
                    let json = JSON(response)
                    sink.put(.Next(Box(json.array!.map({ Subscription(json: $0)}))))
                    sink.put(.Completed)
                },
                failure: { (operation:AFHTTPRequestOperation!, error:NSError!) -> Void in
                    println(error)
                    println(operation.response)
                    sink.put(.Error(error))
            })
            disposable.addDisposable {
                manager.operationQueue.cancelAllOperations()
            }
        }
    }
    func fetchEntries(#streamId: String, newerThan: Int64) -> ColdSignal<JSON> {
        var params = [
                "count": String(FeedlyAPIClientConfig.perPage),
            "newerThan": String(newerThan)
        ]
        return fetchEntries(streamId: streamId, params: params)
    }
    
    func fetchEntries(#streamId: String, continuation: String?) -> ColdSignal<JSON> {
        var params = [
            "count": String(FeedlyAPIClientConfig.perPage)
        ]
        if let c = continuation {
            params["continuation"] = c
        }
        return fetchEntries(streamId: streamId, params: params)
    }
    func fetchAllEntries(#newerThan: Int64) -> ColdSignal<JSON> {
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
    
    func fetchAllEntries(#continuation: String?) -> ColdSignal<JSON> {
        
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

    func fetchEntries(#streamId: String, params: AnyObject) -> ColdSignal<JSON> {
        return ColdSignal { (sink, disposable) in
            let manager = AFHTTPRequestOperationManager()
            let url = NSString(format: "%@/v3/streams/%@/contents",
                                    FeedlyAPIClientConfig.baseUrl,
                                    streamId.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLHostAllowedCharacterSet())!)
            
            manager.requestSerializer.setValue(self.account?.accessToken.accessToken,
                forHTTPHeaderField:"Authorization")
            manager.GET(url, parameters: params,
                success: { (operation:AFHTTPRequestOperation!, response:AnyObject!) -> Void in
                    println(operation.response)
//                    println(response)
                    let json = JSON(response)
                    sink.put(.Next(Box(json)))
                    sink.put(.Completed)

                },
                failure: { (operation:AFHTTPRequestOperation!, error:NSError!) -> Void in
                    println(error)
                    println(operation.response)
                    sink.put(.Error(error))
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
    
    func fetchFeedsByIds(ids: [String]) -> ColdSignal<[Feed]> {
        return ColdSignal { (sink, disposable) in
            let manager = AFHTTPRequestOperationManager()
            manager.requestSerializer = AFJSONRequestSerializer(writingOptions: NSJSONWritingOptions.PrettyPrinted)

            let url = NSString(format: "%@/v3/feeds/.mget",
                FeedlyAPIClientConfig.baseUrl)
        
            manager.requestSerializer.setValue(self.account?.accessToken.accessToken,
                forHTTPHeaderField:"Authorization")

            manager.POST(url, parameters: ids,
                success: { (operation:AFHTTPRequestOperation!, response:AnyObject!) -> Void in
                    println(operation.response)
                    println(response)
                    let json = JSON(response)
                    print(json.array!)
                    sink.put(.Next(Box(json.array!.map({ Feed(json: $0)}))))
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
