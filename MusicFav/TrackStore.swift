//
//  TrackStore.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2/7/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import Realm
import FeedlyKit

class TrackStore: RLMObject {
    dynamic var url:          String = ""
    dynamic var providerRaw:  String = ""
    dynamic var identifier:   String = ""
    dynamic var title:        String = ""
    dynamic var streamUrl:    String = ""
    dynamic var thumbnailUrl: String = ""
    dynamic var duration:     Int = 0

    class var realm: RLMRealm {
        get {
            return RLMRealm.defaultRealm()
        }
    }

    override class func primaryKey() -> String {
        return "url"
    }
    class func findBy(#url: String) -> TrackStore? {
        let results = TrackStore.objectsInRealm(realm, withPredicate: NSPredicate(format: "url = %@", url))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? TrackStore
        }
    }

    class func save(track: Track) {
        if let store = findBy(url: track.url) {
            realm.transactionWithBlock() {
                if let title        = track.title                        { store.title        = title }
                if let streamUrl    = track.streamUrl?.absoluteString    { store.streamUrl    = streamUrl }
                if let thumbnailUrl = track.thumbnailUrl?.absoluteString { store.thumbnailUrl = thumbnailUrl }
            }
        } else {
            let store = track.toStoreObject()
            realm.transactionWithBlock() {
                self.realm.addObject(store)
            }
        }
    }

    class func migration() -> Void {
        RLMRealm.setSchemaVersion(2, forRealmAtPath: RLMRealm.defaultRealmPath()) { (migration, oldVersion) -> Void in
            if (oldVersion < 1) {
                migration.enumerateObjects(TrackStore.className()) { oldObject, newObject in
                    let serviceId = oldObject["serviceId"] as! String
                    newObject["identifier"] = serviceId
                }
            }
            if (oldVersion < 2) {
                migration.enumerateObjects(TrackStore.className()) { oldObject, newObject in
                    let properties = ["title", "streamUrl", "thumbnailUrl"]
                    for prop in properties {
                        let val = oldObject[prop] as! String?
                        if let v = val {
                            newObject[prop] = v
                        }
                    }
                }
            }
        }
    }
}