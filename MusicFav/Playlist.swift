//
//  Playlist.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/28/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import SwiftyJSON

class Playlist {
    let id:           String
    var title:        String
    var tracks:       [Track]
    var thumbnailUrl: NSURL? { return tracks.first?.thumbnailUrl }

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

    func save() {
        PlaylistStore.save(self)
    }

    func remove() {
        PlaylistStore.remove(self)
    }

    func removeTrackAtIndex(index: UInt) {
        PlaylistStore.removeTrackAtIndex(index, playlist: self)
    }

    func appendTrack(track: Track) {
        PlaylistStore.appendTrack(track, playlist: self)
    }

    class func findAll() -> [Playlist] {
        return PlaylistStore.findAll()
    }

    class func removeAll() {
        PlaylistStore.removeAll()
    }
}
