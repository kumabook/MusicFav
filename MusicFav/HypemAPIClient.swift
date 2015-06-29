//
//  HypemAPIClient.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/13/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import SwiftyJSON
import Result
import Box
import ReactiveCocoa
import AFNetworking

class HypemAPIClient {
    let baseUrl = "http://api.hypem.com"
    let apiRoot = "/api"

    static var sharedInstance = HypemAPIClient()

    func getSiteInfo(siteId: Int64) -> SignalProducer<SiteInfo, NSError> {
        return SignalProducer { (sink, disposable) in
            let manager = AFHTTPRequestOperationManager()
            let url = String(format: "%@/get_site_info?siteid=%d", self.baseUrl + self.apiRoot, siteId)
            var operation: AFHTTPRequestOperation? = manager.GET(url, parameters: [:],
                success: { (operation:AFHTTPRequestOperation!, response:AnyObject!) -> Void in
                    let json = JSON(response)
                    sink.put(.Next(Box(SiteInfo(json: json))))
                    sink.put(.Completed)
                },
                failure: { (operation:AFHTTPRequestOperation!, error:NSError!) -> Void in
                    sink.put(.Error(Box(error)))
            })
            disposable.addDisposable {
                operation?.cancel()
            }
        }
    }

    func getAllBlogs() -> SignalProducer<[Blog], NSError> {
        return SignalProducer { (sink, disposable) in
            let manager = AFHTTPRequestOperationManager()
            let url = String(format: "%@/get_all_blogs", self.baseUrl + self.apiRoot)
            let operation = manager.GET(url, parameters: [:],
                success: { (operation:AFHTTPRequestOperation!, response:AnyObject!) -> Void in
                    QueueScheduler().schedule {
                        let json = JSON(response)
                        sink.put(.Next(Box(json.arrayValue.map({ Blog(json: $0) }))))
                        sink.put(.Completed)
                    }
                    return
                },
                failure: { (operation:AFHTTPRequestOperation!, error:NSError!) -> Void in
                    sink.put(.Error(Box(error)))
            })
            disposable.addDisposable {
                operation.cancel()
            }
        }
    }
}