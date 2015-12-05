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
import Alamofire

public class HypemAPIClient {
    let baseUrl = "http://api.hypem.com"
    let apiRoot = "/api"

    public static var sharedInstance = HypemAPIClient()

    public func getSiteInfo(siteId: Int64) -> SignalProducer<SiteInfo, NSError> {
        return SignalProducer { (observer, disposable) in
            let manager = Alamofire.Manager.sharedInstance
            let url = String(format: "%@/get_site_info?siteid=%d", self.baseUrl + self.apiRoot, siteId)
            let request = manager
                .request(.GET, url, parameters: [:], encoding: ParameterEncoding.URL)
                .responseJSON(options: NSJSONReadingOptions()) { response -> Void in
                    if let error = response.result.error {
                        observer.sendFailed(error as NSError)
                    } else if let value = response.result.value {
                        let json = JSON(value)
                        observer.sendNext(SiteInfo(json: json))
                        observer.sendCompleted()
                    }
            }
            disposable.addDisposable {
                request.cancel()
            }
        }
    }

    public func getAllBlogs() -> SignalProducer<[Blog], NSError> {
        return SignalProducer { (observer, disposable) in
            let manager = Alamofire.Manager.sharedInstance
            let url = String(format: "%@/get_all_blogs", self.baseUrl + self.apiRoot)
            let request = manager
                .request(.GET, url, parameters: [:], encoding: ParameterEncoding.URL)
                .responseJSON(options: NSJSONReadingOptions()) { response in
                    if let error = response.result.error {
                        observer.sendFailed(error as NSError)
                    } else if let value = response.result.value {
                        QueueScheduler().schedule {
                            let json = JSON(value)
                            observer.sendNext(json.arrayValue.map({ Blog(json: $0) }))
                            observer.sendCompleted()
                        }
                    }
            }
            disposable.addDisposable {
                request.cancel()
            }
        }
    }
}