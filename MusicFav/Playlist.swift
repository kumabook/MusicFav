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
    let url:   String
    var title: String
    var tracks: [Track]

    init(url: String) {
        self.title  = ""
        self.url    = url
        self.tracks = []
    }

    init(json: JSON) {
        title  = json["title"].string!
        url    = json["url"].string!
        tracks = json["tracks"].array!.map({ Track(json: $0) })
    }
}
