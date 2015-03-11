//
//  PlaylistStore.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2/7/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import Realm

import FeedlyKit

extension RLMArray: SequenceType {
    public func generate() -> NSFastGenerator {
        return NSFastGenerator(self)
    }
}
extension RLMResults: SequenceType {
    public func generate() -> NSFastGenerator {
        return NSFastGenerator(self)
    }
}


class PlaylistStore: RLMObject {
    dynamic var id:     String = ""
    dynamic var title:  String = ""
    dynamic var tracks = RLMArray(objectClassName: TrackStore.className())
    override class func primaryKey() -> String {
        return "id"
    }

    class var realm: RLMRealm {
        get {
            return RLMRealm.defaultRealm()
        }
    }

    class func removeTrackAtIndex(index: UInt, playlist: Playlist) {
        if let store = findBy(id: playlist.id) {
            realm.transactionWithBlock() {
                store.tracks.removeObjectAtIndex(index)
            }
        }
    }

    class func appendTracks(tracks: [Track], playlist: Playlist) {
        let trackStores: [TrackStore] = tracks.map({ track in
            if let trackStore = TrackStore.findBy(url: track.url) { return trackStore }
            else                                                  { return track.toStoreObject() }
        })

        if let store = findBy(id: playlist.id) {
            realm.transactionWithBlock() {
                store.tracks.addObjects(trackStores)
            }
        }
    }

    class func save(playlist: Playlist) {
        if let store = findBy(id: playlist.id) {
            realm.transactionWithBlock() {
                store.title = playlist.title
            }
        } else {
            let store = playlist.toStoreObject()
            realm.transactionWithBlock() {
                self.realm.addObject(store)
            }
        }
    }

    class func findAll() -> [Playlist] {
        var playlists: [Playlist] = []
        for store in PlaylistStore.allObjectsInRealm(realm) {
            playlists.append(Playlist(store: store as PlaylistStore))
        }
        return playlists
    }

    class func findBy(#id: String) -> PlaylistStore? {
        let results = PlaylistStore.objectsInRealm(realm, withPredicate: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? PlaylistStore
        }
    }

    class func remove(playlist: Playlist) {
        if let store = findBy(id: playlist.id) {
            realm.transactionWithBlock() {
                self.realm.deleteObject(store)
            }
        }
    }

    class func removeAll() {
        realm.transactionWithBlock() {
            self.realm.deleteAllObjects()
        }
    }
}