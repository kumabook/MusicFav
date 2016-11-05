//
//  Blog.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/13/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import SwiftyJSON
import ReactiveSwift
import FeedlyKit
import MusicFeeder

open class SiteInfo {
    open let siteId:         Int64
    open let siteName:       String
    open let siteUrl:        String
    open let blogImage:      String?
    open let blogImageSmall: String?
    open let firstPosted:    Int64?
    open let lastPosted:     Int64?
    open let followers:      Int?
    open let isFavorite:     Bool?
    open let regionName:     String?
    open let totalTracks:    Int?
    public init(json: JSON) {
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

open class Blog: FeedlyKit.Stream {
    open override var streamId:    String { return "feed/\(syndUrl)" }
    open override var streamTitle: String { return siteName }
    open let siteId:         Int64
    open let siteName:       String
    open let siteUrl:        String
    open let blogImage:      String?
    open let blogImageSmall: String?
    open var syndUrl:        String
    open let city:           String?
    open let country:        String?
    open var region:         String?
    open let locStr:         String?
    open let email:          String

    open var siteInfo:       SiteInfo?

    public init(json: JSON) {
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

    open func fetchSiteInfo() -> SignalProducer<Blog, NSError> {
        return HypemAPIClient.sharedInstance.getSiteInfo(siteId).map({
            self.siteInfo = $0
            return self
        })
    }

    open override var thumbnailURL: URL? {
        return blogImageSmall.map { URL(string: $0) }.flatMap { $0 }
    }
}
