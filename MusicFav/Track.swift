//
//  Track.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/28/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import SwiftyJSON
import UIKit

enum Provider: String {
    case Youtube    = "Youtube"
    case SoundCloud = "SoundCloud"
}

class Track {
    let provider:     Provider
    let url:          String
    let serviceId:    String
    var title:        String
    var streamUrl:    NSURL?
    var thumbnailUrl: NSURL?
    var duration:     NSTimeInterval

    init(json: JSON) {
        provider  = Provider(rawValue: json["provider"].string!)!
        title     = json["serviceId"].string!
        url       = json["url"].string!
        serviceId = json["serviceId"].string!
        duration  = 0 as NSTimeInterval
    }
    
    func updateProperties(soundCloudAudio: SoundCloudAudio) {
        title        = soundCloudAudio.title
        duration     = NSTimeInterval(soundCloudAudio.duration / 1000)
        streamUrl    = NSURL(string: soundCloudAudio.streamUrl!)
        thumbnailUrl = NSURL(string: soundCloudAudio.artworkUrl!)
    }
    
    func updatePropertiesWithYouTubeVideo(video: XCDYouTubeVideo) {
        let streamURLs = video.streamURLs as [UInt: NSURL]
        title          = video.title
        duration       = video.duration
        streamUrl      = streamURLs[XCDYouTubeVideoQuality.Medium360.rawValue]
        thumbnailUrl   = video.mediumThumbnailURL
    }
}

class SoundCloudAudio {
    let title:               String
    let descriptionProperty: String
    let artworkUrl:         String?
    let streamUrl:          String?
    let duration:           Int
    init(json: JSON) {
        title               = json["title"].string!
        descriptionProperty = json["description"].string!
        artworkUrl          = json["artwork_url"].string?
        streamUrl           = json["stream_url"].string! + "?client_id=" + SoundCloudAPIClientConfig.client_id
        duration            = json["duration"].int!
    }
}

