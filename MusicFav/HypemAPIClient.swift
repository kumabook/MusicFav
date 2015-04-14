//
//  HypemAPIClient.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/13/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import ReactiveCocoa
import SwiftyJSON
import ReactiveCocoa
import LlamaKit
import AFNetworking

class HypemAPIClient {
    let baseUrl = "http://api.hypem.com"
    let apiRoot = "/api"

    class var sharedInstance: HypemAPIClient {
        struct Static {
            static let instance: HypemAPIClient = HypemAPIClient()
        }
        return Static.instance
    }

    func getSiteInfo(siteId: Int64) -> ColdSignal<SiteInfo> {
        return ColdSignal { (sink, disposable) in
            let manager = AFHTTPRequestOperationManager()
            let url = String(format: "%@/get_site_info?siteid=%d", self.baseUrl + self.apiRoot, siteId)
            manager.GET(url, parameters: nil,
                success: { (operation:AFHTTPRequestOperation!, response:AnyObject!) -> Void in
                    let json = JSON(response)
                    sink.put(.Next(Box(SiteInfo(json: json))))
                    sink.put(.Completed)
                },
                failure: { (operation:AFHTTPRequestOperation!, error:NSError!) -> Void in
                    sink.put(.Error(error))
            })
            disposable.addDisposable {
                manager.operationQueue.cancelAllOperations()
            }
        }
    }

    func getAllBlogs() -> ColdSignal<[Blog]> {
        return ColdSignal { (sink, disposable) in
            let manager = AFHTTPRequestOperationManager()
            let url = String(format: "%@/get_all_blogs", self.baseUrl + self.apiRoot)
            manager.GET(url, parameters: nil,
                success: { (operation:AFHTTPRequestOperation!, response:AnyObject!) -> Void in
                    let json = JSON(response)
                    sink.put(.Next(Box(json.arrayValue.map({ Blog(json: $0) }))))
                    sink.put(.Completed)
                },
                failure: { (operation:AFHTTPRequestOperation!, error:NSError!) -> Void in
                    sink.put(.Error(error))
            })
            disposable.addDisposable {
                manager.operationQueue.cancelAllOperations()
            }
        }
    }
}