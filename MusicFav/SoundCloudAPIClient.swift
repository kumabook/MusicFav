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
    static let client_id = "eb7939fb56bae0a6d3412ff21d3ecaba"
}


class SoundCloudAPIClient {
    class var sharedInstance : SoundCloudAPIClient {
        struct Static {
            static let instance : SoundCloudAPIClient = SoundCloudAPIClient()
        }
        return Static.instance
    }
    func fetchTrack(track_id: String) -> ColdSignal<SoundCloudAudio> {
        return ColdSignal { (sink, disposable) in
            let manager = AFHTTPRequestOperationManager()
            let url = NSString(format: "%@/tracks/%@.json?client_id=%@",
                SoundCloudAPIClientConfig.baseUrl, track_id, SoundCloudAPIClientConfig.client_id)
            manager.GET(url, parameters: nil,
                success: { (operation:AFHTTPRequestOperation!, response:AnyObject!) -> Void in
                    let json = JSON(response)
                    sink.put(.Next(Box(SoundCloudAudio(json: json))))
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
    func streamUrl(track_id: Int) -> NSURL {
        return NSURL(string:String(format:"%@/tracks/%@/stream?client_id=%@",
                                SoundCloudAPIClientConfig.baseUrl,
                                track_id,
                                SoundCloudAPIClientConfig.client_id))!
    }
}
