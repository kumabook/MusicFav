//
//  Track.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/28/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import SwiftyJSON
import XCDYouTubeKit
import UIKit

enum Provider: String {
    case Youtube    = "YouTube"
    case SoundCloud = "SoundCloud"
}

class Track {
    let provider:     Provider
    let url:          String
    let identifier:   String
    var title:        String?
    var streamUrl:    NSURL?
    var thumbnailUrl: NSURL?
    var duration:     NSTimeInterval

    init(json: JSON) {
        provider   = Provider(rawValue: json["provider"].stringValue)!
        title      = nil
        url        = json["url"].stringValue
        identifier = json["serviceId"].stringValue
        duration   = 0 as NSTimeInterval
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

    func toStoreObject() -> TrackStore {
        var store          = TrackStore()
        store.url          = url
        store.providerRaw  = provider.rawValue
        store.identifier   = identifier
        store.title        = title
        if let s           = streamUrl    { store.streamUrl    = s.absoluteString }
        if let t           = thumbnailUrl { store.thumbnailUrl = t.absoluteString }
        store.duration     = Int(duration)

        return store
    }

    init(store: TrackStore) {
        provider   = Provider(rawValue: store.providerRaw)!
        title      = store.title
        url        = store.url
        identifier = store.identifier
        duration   = NSTimeInterval(store.duration)

        if let s = store.streamUrl    { streamUrl    = NSURL(string: s) }
        if let t = store.thumbnailUrl { thumbnailUrl = NSURL(string: t) }
    }

    class func findBy(#url: String) {
        TrackStore.findBy(url: url)
    }
}

class SoundCloudAudio {
    let title:               String
    let descriptionProperty: String
    let artworkUrl:         String?
    let streamUrl:          String?
    let duration:           Int
    init(json: JSON) {
        title               = json["title"].stringValue
        descriptionProperty = json["description"].stringValue
        artworkUrl          = json["artwork_url"].string
        streamUrl           = json["stream_url"].stringValue + "?client_id=" + SoundCloudAPIClientConfig.client_id
        duration            = json["duration"].intValue
    }
}

