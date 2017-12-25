//
//  HypemAPIClient.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/13/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import SwiftyJSON
import Result
import ReactiveSwift
import Alamofire

open class HypemAPIClient {
    let baseUrl = "http://api.hypem.com"
    let apiRoot = "/api"

    open static var sharedInstance = HypemAPIClient()

    open func getSiteInfo(_ siteId: Int64) -> SignalProducer<SiteInfo, NSError> {
        return SignalProducer { (observer, disposable) in
            let manager = Alamofire.SessionManager.default
            let url = String(format: "%@/get_site_info?siteid=%d", self.baseUrl + self.apiRoot, siteId)
            let request = manager
                .request(url, method: .get, parameters: [:], encoding: URLEncoding.default)
                .responseJSON(options: JSONSerialization.ReadingOptions()) { response -> Void in
                    if let error = response.result.error {
                        observer.send(error: error as NSError)
                    } else if let value = response.result.value {
                        let json = JSON(value)
                        observer.send(value: SiteInfo(json: json))
                        observer.sendCompleted()
                    }
            }
            disposable.observeEnded {
                request.cancel()
            }
        }
    }

    open func getAllBlogs() -> SignalProducer<[Blog], NSError> {
        return SignalProducer { (observer, disposable) in
            let manager = Alamofire.SessionManager.default
            let url = String(format: "%@/get_all_blogs", self.baseUrl + self.apiRoot)
            let request = manager
                .request(url, method: .get, parameters: [:], encoding: URLEncoding.default)
                .responseJSON(options: JSONSerialization.ReadingOptions()) { response in
                    if let error = response.result.error {
                        observer.send(error: error as NSError)
                    } else if let value = response.result.value {
                        QueueScheduler().schedule {
                            let json = JSON(value)
                            observer.send(value: json.arrayValue.map({ Blog(json: $0) }))
                            observer.sendCompleted()
                        }
                    }
            }
            disposable.observeEnded {
                request.cancel()
            }
        }
    }
}
