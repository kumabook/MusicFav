//
//  Feed.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 1/4/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import SwiftyJSON

class Feed {
    let id:      String
    let title:       String
    let velocity:    Double
    let curated:     Bool
//    let featured:    Bool
    let subscribers: Int
    let website:     String
    init(json: JSON) {
        id          = json["feedId"].string!
        title       = json["title"].string!
        velocity    = json["velocity"].double!
        curated     = json["curated"].bool!
//        featured    = json["featured"].int!
        subscribers = json["subscribers"].int!
        website     = json["website"].string!
    }
}
