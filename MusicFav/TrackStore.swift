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
    dynamic var serviceId:    String = ""
    dynamic var title:        String?
    dynamic var streamUrl:    String?
    dynamic var thumbnailUrl: String?
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
}