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

class Playlist: Equatable, Hashable {
    let id:           String
    var title:        String
    var tracks:       [Track]
    var thumbnailUrl: NSURL? { return tracks.first?.thumbnailUrl }
    var signal:       HotSignal<Int>
    var sink:         SinkOf<Int>

    struct ClassProperty {
        static let pipe    = HotSignal<Event>.pipe()
        static var current = Playlist.findAll()
    }
    enum Event {
        case Created(Playlist)
        case Removed(Playlist)
        case Updated(Playlist)
        case TracksAdded( Playlist, [Track])
        case TrackRemoved(Playlist, Track, Int)
        case TrackUpdated(Playlist, Track)
    }

    class var shared: (signal: HotSignal<Event>, sink: SinkOf<Event>, current: [Playlist]) {
        get { return (signal: ClassProperty.pipe.0,
                        sink: ClassProperty.pipe.1,
                     current: ClassProperty.current) }
    }

    class func notifyChange(event: Event) {
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

        shared.sink.put(event)
    }

    private class func dateFormatter() -> NSDateFormatter {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        return dateFormatter
    }

    init(title: String) {
        self.id     = "created-\(Playlist.dateFormatter().stringFromDate(NSDate()))"
        self.title  = title
        self.tracks = []
        let pipe    = HotSignal<Int>.pipe()
        self.signal = pipe.0
        self.sink   = pipe.1
    }

    init(json: JSON) {
        id     = json["url"].stringValue
        title  = json["title"].stringValue
        tracks = json["tracks"].arrayValue.map({ Track(json: $0) })
        let pipe    = HotSignal<Int>.pipe()
        self.signal = pipe.0
        self.sink   = pipe.1
    }

    init(store: PlaylistStore) {
        id     = store.id
        title  = store.title
        tracks = [] as [Track]
        for trackStore in store.tracks {
            tracks.append(Track(store:trackStore as TrackStore))
        }
        let pipe    = HotSignal<Int>.pipe()
        self.signal = pipe.0
        self.sink   = pipe.1
    }

    var hashValue: Int {
        return id.hashValue
    }

    func toStoreObject() -> PlaylistStore {
        let store    = PlaylistStore()
        store.id     = id
        store.title  = title
        store.tracks.addObjects(tracks.map({ $0.toStoreObject() }))
        return store
    }

    func create() {
        PlaylistStore.save(self)
        Playlist.notifyChange(.Created(self))
    }

    func save() {
        PlaylistStore.save(self)
        Playlist.notifyChange(.Updated(self))
    }

    func remove() {
        PlaylistStore.remove(self)
        Playlist.notifyChange(.Removed(self))
    }

    func removeTrackAtIndex(index: UInt) {
        PlaylistStore.removeTrackAtIndex(index, playlist: self)
        let track = tracks.removeAtIndex(Int(index))
        Playlist.notifyChange(.TrackRemoved(self, track, Int(index)))
    }

    func appendTracks(tracks: [Track]) {
        PlaylistStore.appendTracks(tracks, playlist: self)
        self.tracks.extend(tracks)
        Playlist.notifyChange(.TracksAdded(self, tracks))
    }

    class func findAll() -> [Playlist] {
        return PlaylistStore.findAll()
    }

    class func removeAll() {
        PlaylistStore.removeAll()
    }
}

func ==(lhs: Playlist, rhs: Playlist) -> Bool {
    return lhs.id == rhs.id
}
