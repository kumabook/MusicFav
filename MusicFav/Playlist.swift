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

class Playlist: Equatable {
    let id:           String
    var title:        String
    var tracks:       [Track]
    var thumbnailUrl: NSURL? { return tracks.first?.thumbnailUrl }

    struct ClassProperty {
        static let pipe    = HotSignal<Event>.pipe()
        static var current = Playlist.findAll()
    }
    enum Action {
        case Create
        case Remove
        case Update
    }
    typealias Event = (action: Action, value: Playlist)

    class var shared: (signal: HotSignal<Event>, sink: SinkOf<Event>, current: [Playlist]) {
        get { return (signal: ClassProperty.pipe.0,
                        sink: ClassProperty.pipe.1,
                     current: ClassProperty.current) }
    }

    class func notifyChange(event: Event) {
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
    }

    init(json: JSON) {
        id     = json["url"].stringValue
        title  = json["title"].stringValue
        tracks = json["tracks"].arrayValue.map({ Track(json: $0) })
    }

    init(store: PlaylistStore) {
        id     = store.id
        title  = store.title
        tracks = [] as [Track]
        for trackStore in store.tracks {
            tracks.append(Track(store:trackStore as TrackStore))
        }
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
        Playlist.notifyChange((Action.Create, self))
    }

    func save() {
        PlaylistStore.save(self)
        Playlist.notifyChange((Action.Update, self))
    }

    func remove() {
        PlaylistStore.remove(self)
        Playlist.notifyChange((Action.Remove, self))
    }

    func removeTrackAtIndex(index: UInt) {
        PlaylistStore.removeTrackAtIndex(index, playlist: self)
        tracks.removeAtIndex(Int(index))
        Playlist.notifyChange((Action.Update, self))
    }

    func appendTracks(tracks: [Track]) {
        PlaylistStore.appendTracks(tracks, playlist: self)
        self.tracks.extend(tracks)
        Playlist.notifyChange((Action.Update, self))
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
