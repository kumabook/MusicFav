//
//  Channel.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 7/11/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import SwiftyJSON
import FeedlyKit
import MusicFeeder

open class GuideCategory: Hashable, Equatable {
    open let etag:      String
    open let id:        String
    open let kind:      String
    open let channelId: String!
    open let title:     String!
    open var hashValue: Int { return id.hashValue }

    public init(json: JSON) {
        etag = json["etag"].stringValue
        id   = json["id"].stringValue
        kind = json["kind"].stringValue
        if let snippet = json["snippet"].dictionary {
            channelId = snippet["channelId"]!.stringValue
            title     = snippet["title"]!.stringValue
        } else {
            channelId = nil
            title     = nil
        }
    }
}

public func ==(lhs: GuideCategory, rhs: GuideCategory) -> Bool {
    return lhs.id == rhs.id
}

protocol YouTubeResource {
    static var url: String { get }
    static var params: [String:String] { get }
    init(json: JSON)
}

open class ChannelResource: FeedlyKit.Stream {
    open override var streamTitle: String { return title }
    open override var streamId:    String { return "feed/https://www.youtube.com/feeds/videos.xml?channel_id=\(id)" }
    open let etag:        String
    open let id:          String
    open let kind:        String
    open let title:       String!
    open let description: String!
    open let publishedAt: String?
    open let thumbnails: [String:String]
    open let resourceId: [String:String]
    open static func resourceId(_ snippet: [String: JSON]) -> [String:String] {
        var resId: [String:String] = [:]
        if let r = snippet["resourceId"]?.dictionary {
            for key in r.keys {
                resId[key] = r[key]!.stringValue
            }
        }
        return resId
    }
    open static func thumbnails(_ snippet: [String: JSON]) -> [String:String] {
        var thumbs: [String:String] = [:]
        if let d = snippet["thumbnails"]?.dictionary {
            for k in d.keys {
                thumbs[k] = d[k]!["url"].stringValue
            }
        }
        return thumbs
    }
    public required init(json: JSON) {
        let snippet = json["snippet"].dictionaryValue
        etag        = json["etag"].stringValue
        id          = json["id"].stringValue
        kind        = json["kind"].stringValue
        title       = snippet["title"]!.stringValue
        description = snippet["description"]!.stringValue
        publishedAt = snippet["publishedAt"]?.string
        thumbnails  = ChannelResource.thumbnails(snippet)
        resourceId  = ChannelResource.resourceId(snippet)
        super.init()
    }
    public init(etag: String,
                  id: String,
                kind: String,
               title: String,
         description: String,
         publishedAt: String?,
          thumbnails: [String:String],
          resourceId: [String:String]) {
            self.etag        = etag
            self.id          = id
            self.kind        = kind
            self.title       = title
            self.description = description
            self.publishedAt = publishedAt
            self.thumbnails  = thumbnails
            self.resourceId  = resourceId
            super.init()
    }
    open override var thumbnailURL: URL? {
             if let url = thumbnails["default"] { return URL(string: url) }
        else if let url = thumbnails["medium"]  { return URL(string: url) }
        else if let url = thumbnails["high"]    { return URL(string: url) }
        else                                    { return nil }
    }
}

open class Channel: ChannelResource, YouTubeResource {
    open class var url: String { return "https://www.googleapis.com/youtube/v3/channels" }
    open class var params: [String:String] { return [:] }

    public convenience init(subscription: YouTubeSubscription) {
        self.init(etag: subscription.etag,
                    id: subscription.resourceId["channelId"]!,
                  kind: subscription.resourceId["kind"]!,
                 title: subscription.title,
           description: subscription.description,
           publishedAt: subscription.publishedAt,
            thumbnails: subscription.thumbnails,
            resourceId: subscription.resourceId)
    }
}

open class YouTubeSubscription: ChannelResource, YouTubeResource {
    open class var url: String { return "https://www.googleapis.com/youtube/v3/subscriptions" }
    open class var params: [String:String] { return ["mine": "true"] }
}

open class MyChannel: Channel {
    var relatedPlaylists: [String: String]

    public required init(json: JSON) {
        self.relatedPlaylists = [:]
        super.init(json: json)
        if let contentDetails = json["contentDetails"].dictionary {
            if let relatedPlaylists = contentDetails["relatedPlaylists"]?.dictionary {
                for key in relatedPlaylists.keys {
                    self.relatedPlaylists[key] = relatedPlaylists[key]!.stringValue
                }
            }
        }
    }
}
