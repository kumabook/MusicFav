//
//  Track.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/28/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import SwiftyJSON
import ReactiveCocoa
import LlamaKit
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
        provider    = Provider(rawValue: json["provider"].stringValue)!
        title       = nil
        url         = json["url"].stringValue
        identifier  = json["identifier"].stringValue
        duration    = 0 as NSTimeInterval
    }

    init(store: TrackStore) {
        provider    = Provider(rawValue: store.providerRaw)!
        title       = store.title
        url         = store.url
        identifier  = store.identifier
        duration    = NSTimeInterval(store.duration)

        if let url = NSURL(string: store.streamUrl)    { streamUrl    = url }
        if let url = NSURL(string: store.thumbnailUrl) { thumbnailUrl = url }
    }

    func updateProperties(soundCloudAudio: SoundCloudAudio) {
        title        = soundCloudAudio.title
        duration     = NSTimeInterval(soundCloudAudio.duration / 1000)
        if let sUrl = soundCloudAudio.streamUrl {
            streamUrl = NSURL(string: sUrl)
        }
        if let aUrl = soundCloudAudio.artworkUrl {
            thumbnailUrl = NSURL(string: aUrl)
        }
//        TrackStore.save(self)
    }
    
    func updatePropertiesWithYouTubeVideo(video: XCDYouTubeVideo) {
        title          = video.title
        duration       = video.duration
        streamUrl      = video.streamURLs[XCDYouTubeVideoQuality.Medium360.rawValue] as? NSURL
        thumbnailUrl   = video.mediumThumbnailURL
//        TrackStore.save(self)
    }

    func toStoreObject() -> TrackStore {
        var store            = TrackStore()
        store.url            = url
        store.providerRaw    = provider.rawValue
        store.identifier     = identifier
        if let _title        = title                        { store.title        = _title }
        if let _streamUrl    = streamUrl?.absoluteString    { store.streamUrl    = _streamUrl }
        if let _thumbnailUrl = thumbnailUrl?.absoluteString { store.thumbnailUrl = _thumbnailUrl }
        store.duration       = Int(duration)

        return store
    }

    func fetchTrackDetail(errorOnFailure: Bool) -> ColdSignal<Track>{
        switch provider {
        case .Youtube:
            return XCDYouTubeClient.defaultClient().fetchVideo(identifier, errorOnFailure: errorOnFailure)
                .deliverOn(MainScheduler())
                .map({
                    self.updatePropertiesWithYouTubeVideo($0)
                    return self
                })
        case .SoundCloud:
            return SoundCloudAPIClient.sharedInstance.fetchTrack(identifier, errorOnFailure: errorOnFailure)
                .deliverOn(MainScheduler())
                .map({
                    self.updateProperties($0)
                    return self
                })
        }
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

