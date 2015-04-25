//
//  Playlist.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/28/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import SwiftyJSON
import ReactiveCocoa
import LlamaKit

public class Playlist: Equatable, Hashable {
    public   let id:           String
    public   var title:        String
    public   var tracks:       [Track]
    public   var thumbnailUrl: NSURL? { return tracks.first?.thumbnailUrl }
    public   var signal:       Signal<Int, NSError>
    internal var sink:         SinkOf<ReactiveCocoa.Event<Int, NSError>>

    struct ClassProperty {
        static let pipe    = Signal<Event, NSError>.pipe()
        static var current = Playlist.findAll()
    }
    public enum Event {
        case Created(Playlist)
        case Removed(Playlist)
        case Updated(Playlist)
        case TracksAdded( Playlist, [Track])
        case TrackRemoved(Playlist, Track, Int)
        case TrackUpdated(Playlist, Track)
    }

    public class var shared: (signal: Signal<Event, NSError>, sink: SinkOf<ReactiveCocoa.Event<Event, NSError>>, current: [Playlist]) {
        get { return (signal: ClassProperty.pipe.0,
                        sink: ClassProperty.pipe.1,
                     current: ClassProperty.current) }
    }

    public class func notifyChange(event: Event) {
        switch event {
        case .Created(let playlist):
            ClassProperty.current.append(playlist)
        case .Removed(let playlist):
            if let index = find(ClassProperty.current, playlist) {
                ClassProperty.current.removeAtIndex(index)
            }
        case .Updated(let playlist):
            if let index = find(ClassProperty.current, playlist) {
                ClassProperty.current[index] = playlist
            }
        case .TracksAdded(let playlist, let tracks):
            break
        case .TrackRemoved(let playlist, let track, let index):
            break
        case .TrackUpdated(let playlist, let tracks):
            break
        }

        shared.sink.put(ReactiveCocoa.Event<Event, NSError>.Next(Box(event)))
    }

    private class func dateFormatter() -> NSDateFormatter {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        return dateFormatter
    }

    public init(title: String) {
        self.id     = "created-\(Playlist.dateFormatter().stringFromDate(NSDate()))"
        self.title  = title
        self.tracks = []
        let pipe    = Signal<Int, NSError>.pipe()
        self.signal = pipe.0
        self.sink   = pipe.1
    }

    public init(json: JSON) {
        id     = json["url"].stringValue
        title  = json["title"].stringValue
        tracks = json["tracks"].arrayValue.map({ Track(json: $0) })
        let pipe    = Signal<Int, NSError>.pipe()
        self.signal = pipe.0
        self.sink   = pipe.1
    }

    public init(store: PlaylistStore) {
        id     = store.id
        title  = store.title
        tracks = [] as [Track]
        for trackStore in store.tracks {
            tracks.append(Track(store:trackStore as! TrackStore))
        }
        let pipe    = Signal<Int, NSError>.pipe()
        self.signal = pipe.0
        self.sink   = pipe.1
    }

    public var hashValue: Int {
        return id.hashValue
    }

    internal func toStoreObject() -> PlaylistStore {
        let store    = PlaylistStore()
        store.id     = id
        store.title  = title
        store.tracks.addObjects(tracks.map({ $0.toStoreObject() }))
        return store
    }

    public func create() -> Bool {
        if PlaylistStore.create(self) {
            Playlist.notifyChange(.Created(self))
            return true
        } else {
            return false
        }
    }

    public func save() -> Bool {
        if PlaylistStore.save(self) {
            Playlist.notifyChange(.Updated(self))
            return true
        } else {
            return false
        }
    }

    public func remove() {
        PlaylistStore.remove(self)
        Playlist.notifyChange(.Removed(self))
    }

    public func removeTrackAtIndex(index: UInt) {
        PlaylistStore.removeTrackAtIndex(index, playlist: self)
        let track = tracks.removeAtIndex(Int(index))
        Playlist.notifyChange(.TrackRemoved(self, track, Int(index)))
    }

    public func appendTracks(tracks: [Track]) {
        PlaylistStore.appendTracks(tracks, playlist: self)
        self.tracks.extend(tracks)
        Playlist.notifyChange(.TracksAdded(self, tracks))
    }

    public class func findAll() -> [Playlist] {
        return PlaylistStore.findAll()
    }

    public class func removeAll() {
        PlaylistStore.removeAll()
    }

    public class func createDefaultPlaylist() {
        Playlist(title: "Favorite").save()
    }
}

public func ==(lhs: Playlist, rhs: Playlist) -> Bool {
    return lhs.id == rhs.id
}
