//
//  Blog.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/13/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import SwiftyJSON
import ReactiveCocoa
import LlamaKit
import FeedlyKit

class Blog {
    let siteId:         Int64
    let siteName:       String
    let siteUrl:        String
    let syndUrl:        String
    let email:          String
    let blogImage:      String?
    let blogImageSmall: String?
    let firstPosted:    Int64?
    let followers:      Int?
    let lastPosted:     Int64?
    let totalTracks:    Int?
    let city:           String?
    let country:        String?
    let locStr:         String?
    let regionName:     String?
    let isFavorite:     Bool?

    init(json: JSON) {
        self.siteId         = json["siteid"].int64Value
        self.siteName       = json["sitename"].stringValue
        self.siteUrl        = json["siteurl"].stringValue
        self.syndUrl        = json["syndurl"].stringValue
        self.email          = json["email"].stringValue
        self.blogImage      = json["blog_image"].string
        self.blogImageSmall = json["blog_image_small"].string
        self.firstPosted    = json["first_posted"].int64Value
        self.followers      = json["followers"].intValue
        self.lastPosted     = json["last_posted"].int64Value
        self.totalTracks    = json["total_tracks"].intValue
        self.regionName     = json["region_name"].string
        self.isFavorite     = json["is_favorite"].bool
    }

    func fetchDetail() -> ColdSignal<Blog> {
        return HypemAPIClient.sharedInstance.getSiteInfo(siteId)
    }
}