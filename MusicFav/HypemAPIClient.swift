//
//  HypemAPIClient.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/13/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import SwiftyJSON
import Result
import ReactiveCocoa
import AFNetworking

public class HypemAPIClient {
    let baseUrl = "http://api.hypem.com"
    let apiRoot = "/api"

    public static var sharedInstance = HypemAPIClient()

    public func getSiteInfo(siteId: Int64) -> SignalProducer<SiteInfo, NSError> {
        return SignalProducer { (sink, disposable) in
            let manager = AFHTTPRequestOperationManager()
            let url = String(format: "%@/get_site_info?siteid=%d", self.baseUrl + self.apiRoot, siteId)
            let operation: AFHTTPRequestOperation? = manager.GET(url, parameters: [:],
                success: { (operation:AFHTTPRequestOperation!, response:AnyObject!) -> Void in
                    let json = JSON(response)
                    sink(.Next(SiteInfo(json: json)))
                    sink(.Completed)
                },
                failure: { (operation:AFHTTPRequestOperation!, error:NSError!) -> Void in
                    sink(.Error(error))
            })
            disposable.addDisposable {
                operation?.cancel()
            }
        }
    }

    public func getAllBlogs() -> SignalProducer<[Blog], NSError> {
        return SignalProducer { (sink, disposable) in
            let manager = AFHTTPRequestOperationManager()
            let url = String(format: "%@/get_all_blogs", self.baseUrl + self.apiRoot)
            let operation = manager.GET(url, parameters: [:],
                success: { (operation:AFHTTPRequestOperation!, response:AnyObject!) -> Void in
                    QueueScheduler().schedule {
                        let json = JSON(response)
                        sink(.Next(json.arrayValue.map({ Blog(json: $0) })))
                        sink(.Completed)
                    }
                    return
                },
                failure: { (operation:AFHTTPRequestOperation!, error:NSError!) -> Void in
                    sink(.Error(error))
            })
            disposable.addDisposable {
                operation?.cancel()
            }
        }
    }
}