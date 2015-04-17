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

struct SoundCloudAPIClientConfig {
    static let baseUrl   = "http://api.soundcloud.com"
    static var client_id = ""
}


class SoundCloudAPIClient {
    class var sharedInstance : SoundCloudAPIClient {
        struct Static {
            static let instance : SoundCloudAPIClient = SoundCloudAPIClient()
        }
        return Static.instance
    }

    init() {
        loadConfig()
    }
    func loadConfig() {
        let bundle = NSBundle.mainBundle()
        if let path = bundle.pathForResource("soundcloud", ofType: "json") {
            let data     = NSData(contentsOfFile: path)
            let jsonObject: AnyObject? = NSJSONSerialization.JSONObjectWithData(data!,
                options: NSJSONReadingOptions.MutableContainers,
                error: nil)
            if let obj: AnyObject = jsonObject {
                let json = JSON(obj)
                if let clientId = json["client_id"].string {
                   SoundCloudAPIClientConfig.client_id = clientId
                }
            }
        }
    }

    func fetchTrack(track_id: String, errorOnFailure: Bool) -> ColdSignal<SoundCloudAudio> {
        return ColdSignal { (sink, disposable) in
            let manager = AFHTTPRequestOperationManager()
            manager.completionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
            let url = NSString(format: "%@/tracks/%@.json?client_id=%@",
                SoundCloudAPIClientConfig.baseUrl, track_id, SoundCloudAPIClientConfig.client_id)
            manager.GET(url, parameters: nil,
                success: { (operation:AFHTTPRequestOperation!, response:AnyObject!) -> Void in
                    let json = JSON(response)
                    sink.put(.Next(Box(SoundCloudAudio(json: json))))
                    sink.put(.Completed)
                },
                failure: { (operation:AFHTTPRequestOperation!, error:NSError!) -> Void in
                    if errorOnFailure {
                        sink.put(.Error(error))
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
                                SoundCloudAPIClientConfig.baseUrl,
                                track_id,
                                SoundCloudAPIClientConfig.client_id))!
    }
}
