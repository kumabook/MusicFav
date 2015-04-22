//
//  SoundCloudAPIClient.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/30/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import SwiftyJSON
import ReactiveCocoa
import LlamaKit
import AFNetworking


class SoundCloudAPIClient {
    private struct ClassProperty {
        static var instance: SoundCloudAPIClient = SoundCloudAPIClient(clientId: clientId)
        static var baseUrl = "http://api.soundcloud.com"
        static var clientId = "Put_your_SoundCloud_app_client_id"
    }

    class var sharedInstance : SoundCloudAPIClient {
        return ClassProperty.instance
    }

    class func loadConfig() {
        let bundle = NSBundle.mainBundle()
        if let path = bundle.pathForResource("soundcloud", ofType: "json") {
            let data     = NSData(contentsOfFile: path)
            let jsonObject: AnyObject? = NSJSONSerialization.JSONObjectWithData(data!,
                options: NSJSONReadingOptions.MutableContainers,
                error: nil)
            if let obj: AnyObject = jsonObject {
                let json = JSON(obj)
                if let clientId = json["client_id"].string {
                    ClassProperty.clientId = clientId
                }
            }
        }
    }

    let clientId: String

    init(clientId: String) {
        self.clientId = clientId
    }

    func fetchTrack(track_id: String, errorOnFailure: Bool) -> SignalProducer<SoundCloudAudio, NSError> {
        return SignalProducer { (sink, disposable) in
            let manager = AFHTTPRequestOperationManager()
            manager.completionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
            let url = String(format: "%@/tracks/%@.json?client_id=%@", ClassProperty.baseUrl, track_id, self.clientId)
            manager.GET(url, parameters: nil,
                success: { (operation:AFHTTPRequestOperation!, response:AnyObject!) -> Void in
                    let json = JSON(response)
                    sink.put(.Next(Box(SoundCloudAudio(json: json))))
                    sink.put(.Completed)
                },
                failure: { (operation:AFHTTPRequestOperation!, error:NSError!) -> Void in
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
    func streamUrl(track_id: Int) -> NSURL {
        return NSURL(string:String(format:"%@/tracks/%@/stream?client_id=%@",
                                ClassProperty.baseUrl,
                                track_id,
                                clientId))!
    }
}
