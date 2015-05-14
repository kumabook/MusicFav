//
//  MusicFavAPIClient.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/1/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import SwiftyJSON
import ReactiveCocoa
import LlamaKit
import AFNetworking

class MusicFavAPIClient {
    static let baseUrl   = "http://musicfav-cloud.herokuapp.com"
    static var sharedInstance = MusicFavAPIClient()
    func playlistify(targetUrl: NSURL, errorOnFailure: Bool) -> SignalProducer<Playlist, NSError> {
        return SignalProducer { (sink, disposable) in
            let manager = AFHTTPRequestOperationManager()
            manager.completionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
            let url = String(format: "%@/playlistify?url=%@", MusicFavAPIClient.baseUrl, targetUrl)
            manager.GET(url, parameters: nil,
                success: { (operation:AFHTTPRequestOperation!, response:AnyObject!) -> Void in
                    let json = JSON(response)
                    sink.put(.Next(Box(Playlist(json: json))))
                    sink.put(.Completed)
                },
                failure: { (operation:AFHTTPRequestOperation!, error:NSError!) -> Void in
                    println(error)
                    println(operation.response)
                    if errorOnFailure {
                        sink.put(.Error(Box(error)))
                    } else {
                        sink.put(.Completed)
                    }
            })
            disposable.addDisposable {
                manager.operationQueue.cancelAllOperations()
            }
        }
    }
}