//
//  Blog.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/13/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import SwiftyJSON
import ReactiveCocoa
import FeedlyKit

class SiteInfo {
    let siteId:         Int64
    let siteName:       String
    let siteUrl:        String
    let blogImage:      String?
    let blogImageSmall: String?
    let firstPosted:    Int64?
    let lastPosted:     Int64?
    let followers:      Int?
    let isFavorite:     Bool?
    let regionName:     String?
    let totalTracks:    Int?
    init(json: JSON) {
        self.siteId         = json["siteid"].int64Value
        self.siteName       = json["sitename"].stringValue
        self.siteUrl        = json["siteurl"].stringValue
        self.blogImage      = json["blog_image"].string
        self.blogImageSmall = json["blog_image_small"].string
        self.firstPosted    = json["first_posted"].int64Value
        self.followers      = json["followers"].intValue
        self.lastPosted     = json["last_posted"].int64Value
        self.totalTracks    = json["total_tracks"].intValue
        self.regionName     = json["region_name"].string
        self.isFavorite     = json["is_favorite"].bool
    }
}

class Blog {
    let siteId:         Int64
    let siteName:       String
    let siteUrl:        String
    let blogImage:      String?
    let blogImageSmall: String?
    var syndUrl:        String
    let city:           String?
    let country:        String?
    var region:         String?
    let locStr:         String?
    let email:          String

    var siteInfo:       SiteInfo?

    init(json: JSON) {
        self.siteId         = json["siteid"].int64Value
        self.siteName       = json["sitename"].stringValue
        self.siteUrl        = json["siteurl"].stringValue
        self.syndUrl        = json["syndurl"].stringValue
        self.blogImage      = json["blog_image"].string
        self.blogImageSmall = json["blog_image_small"].string
        self.city           = json["city"].string
        self.country        = json["country"].string
        self.region         = json["region"].string
        self.locStr         = json["loc_str"].string
        self.email          = json["email"].stringValue
    }

    var feedId: String {
        return "feed/\(syndUrl)"
    }

    func fetchSiteInfo() -> SignalProducer<Blog, NSError> {
        return HypemAPIClient.sharedInstance.getSiteInfo(siteId) |> map({
            self.siteInfo = $0
            return self
        })
    }
}
