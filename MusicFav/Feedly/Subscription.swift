//
//  Subscription.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/21/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import SwiftyJSON

class Subscription: NSObject {
    let id: String
    let updated: Int
    let title: String
//    let categories: String
//    let visualUrl: String
    let website: String
    init(json:JSON) {
        self.id         = json["id"].string!
        self.updated    = json["updated"].int!
        self.title      = json["title"].string!
//        self.categories = json["categories"].string!
//        self.visualUrl  = json["visualUrl"].string!
        self.website    = json["website"].string!
    }
}
