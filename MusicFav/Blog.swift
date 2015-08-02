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
import MusicFeeder

public class SiteInfo {
    public let siteId:         Int64
    public let siteName:       String
    public let siteUrl:        String
    public let blogImage:      String?
    public let blogImageSmall: String?
    public let firstPosted:    Int64?
    public let lastPosted:     Int64?
    public let followers:      Int?
    public let isFavorite:     Bool?
    public let regionName:     String?
    public let totalTracks:    Int?
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

public class Blog: Subscribable {
    public let siteId:         Int64
    public let siteName:       String
    public let siteUrl:        String
    public let blogImage:      String?
    public let blogImageSmall: String?
    public var syndUrl:        String
    public let city:           String?
    public let country:        String?
    public var region:         String?
    public let locStr:         String?
    public let email:          String

    public var siteInfo:       SiteInfo?

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

    public var feedId: String {
        return "feed/\(syndUrl)"
    }

    public func fetchSiteInfo() -> SignalProducer<Blog, NSError> {
        return HypemAPIClient.sharedInstance.getSiteInfo(siteId) |> map({
            self.siteInfo = $0
            return self
        })
    }

    public func toSubscription() -> Subscription {
        return Subscription(id: feedId, title: siteName, categories: [])
    }
}
