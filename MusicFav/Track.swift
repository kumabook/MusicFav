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

public enum Provider: String {
    case Youtube    = "YouTube"
    case SoundCloud = "SoundCloud"
}

public class Track {
    public enum Status {
        case Init
        case Loading
        case Available
        case Unavailable
    }
    public let provider:     Provider
    public let url:          String
    public let identifier:   String
    public var title:        String?
    public var streamUrl:    NSURL?
    public var thumbnailUrl: NSURL?
    public var duration:     NSTimeInterval

    public var status:   Status { return _status }
    private var _status: Status

    public init(provider: Provider, url: String, identifier: String, title: String?) {
        self.provider   = provider
        self.url        = url
        self.identifier = identifier
        self.title      = title
        self.duration   = 0 as NSTimeInterval
        self._status    = .Init
    }

    public init(json: JSON) {
        provider    = Provider(rawValue: json["provider"].stringValue)!
        title       = nil
        url         = json["url"].stringValue
        identifier  = json["identifier"].stringValue
        duration    = 0 as NSTimeInterval
        _status     = .Init
    }

    public init(store: TrackStore) {
        provider    = Provider(rawValue: store.providerRaw)!
        title       = store.title
        url         = store.url
        identifier  = store.identifier
        duration    = NSTimeInterval(store.duration)
        if let url = NSURL(string: store.streamUrl) {
            streamUrl    = url
            _status      = .Available
        } else {
            _status      = .Init
        }
        if let url = NSURL(string: store.thumbnailUrl) {
            thumbnailUrl = url
        }
    }

    public func create() -> Bool {
        return TrackStore.create(self)
    }

    public func save() -> Bool {
        return TrackStore.save(self)
    }

    public func updateProperties(soundCloudAudio: SoundCloudAudio) {
        title        = soundCloudAudio.title
        duration     = NSTimeInterval(soundCloudAudio.duration / 1000)
        if let sUrl = soundCloudAudio.streamUrl {
            streamUrl = NSURL(string: sUrl)
            _status   = .Available
        }
        if let aUrl = soundCloudAudio.artworkUrl {
            thumbnailUrl = NSURL(string: aUrl)
        }
//      save()
    }
    
    public func updatePropertiesWithYouTubeVideo(video: XCDYouTubeVideo) {
        title          = video.title
        duration       = video.duration
        streamUrl      = video.streamURLs[XCDYouTubeVideoQuality.Medium360.rawValue] as? NSURL
        thumbnailUrl   = video.mediumThumbnailURL
        _status        = .Available
//      save()
    }

    internal func toStoreObject() -> TrackStore {
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

    public func fetchTrackDetail(errorOnFailure: Bool) -> SignalProducer<Track, NSError>{
        _status = .Loading
        switch provider {
        case .Youtube:
            return SignalProducer<Track, NSError> { (sink, disposable) in
                XCDYouTubeClient.defaultClient().fetchVideo(self.identifier).start(
                    next: { video in
                        self.updatePropertiesWithYouTubeVideo(video)
                        sink.put(.Next(Box(self)))
                        sink.put(.Completed)
                    }, error: { error in
                        self._status = .Unavailable
                        sink.put(.Next(Box(self)))
                        sink.put(.Completed)
                    }, completed: {
                    }, interrupted: {
                        self._status = .Unavailable
                        sink.put(.Next(Box(self)))
                        sink.put(.Completed)
                    })
                return
            }
        case .SoundCloud:
            return SignalProducer<Track, NSError> { (sink, disposable) in
                SoundCloudAPIClient.sharedInstance.fetchTrack(self.identifier).start(
                    next: { track in
                        self.updateProperties(track)
                        sink.put(.Next(Box(self)))
                        sink.put(.Completed)
                    }, error: { error in
                        self._status = .Unavailable
                        sink.put(.Next(Box(self)))
                        sink.put(.Completed)
                    }, completed: {
                    }, interrupted: {
                        self._status = .Unavailable
                        sink.put(.Next(Box(self)))
                        sink.put(.Completed)
                })
                return
            }
        }
    }

    public class func findBy(#url: String) -> Track? {
        if let store = TrackStore.findBy(url: url) {
            return Track(store: store)
        }
        return nil
    }

    public class func findAll() -> [Track] {
        return TrackStore.findAll().map({ Track(store: $0) })
    }

    public class func removeAll() {
        return TrackStore.removeAll()
    }
}

public class SoundCloudAudio {
    let title:               String
    let descriptionProperty: String
    let artworkUrl:         String?
    let streamUrl:          String?
    let duration:           Int
    init(json: JSON) {
        title               = json["title"].stringValue
        descriptionProperty = json["description"].stringValue
        artworkUrl          = json["artwork_url"].string
        streamUrl           = json["stream_url"].stringValue + "?client_id=" + SoundCloudAPIClient.sharedInstance.clientId
        duration            = json["duration"].intValue
    }
}

