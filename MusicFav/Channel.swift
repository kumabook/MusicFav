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

public class GuideCategory: Hashable, Equatable {
    public let etag:      String
    public let id:        String
    public let kind:      String
    public let channelId: String!
    public let title:     String!
    public var hashValue: Int { return id.hashValue }

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

public class YouTubeResource: Stream {
    public class var url: String { return "https://www.googleapis.com/youtube/v3/resouce_name" }
    public class var params: [String:String] { return [:] }
    public override var streamTitle: String { return title }
    public let etag:        String
    public let id:          String
    public let kind:        String
    public let title:       String!
    public let description: String!
    public let publishedAt: String?
    public let thumbnails: [String:String]
    public let resourceId: [String:String]
    public convenience init(json: JSON) {
        let snippet = json["snippet"].dictionaryValue
        let d       = snippet["thumbnails"]!.dictionary!
        var resId: [String:String] = [:]
        if let r = snippet["resourceId"]?.dictionary {
            for key in r.keys {
                resId[key] = r[key]!.stringValue
            }
        }
        var thumbs: [String:String] = [:]
        for k in d.keys {
            thumbs[k] = d[k]!["url"].stringValue
        }
        self.init(etag: json["etag"].stringValue,
                    id: json["id"].stringValue,
                  kind: json["kind"].stringValue,
                 title: snippet["title"]!.stringValue,
           description: snippet["description"]!.stringValue,
           publishedAt: snippet["publishedAt"]?.string,
            thumbnails: thumbs,
            resourceId: resId)
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
    }
    public override var thumbnailURL: NSURL? {
             if let url = thumbnails["default"] { return NSURL(string: url) }
        else if let url = thumbnails["medium"]  { return NSURL(string: url) }
        else if let url = thumbnails["high"]    { return NSURL(string: url) }
        else                                    { return nil }
    }
}

public class Channel: YouTubeResource {
    public override class var url: String { return "https://www.googleapis.com/youtube/v3/channels" }
    public override var streamId:    String { return "feed/https://www.youtube.com/feeds/videos.xml?channel_id=\(id)" }
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

public class YouTubeSubscription: YouTubeResource {
    public override class var url: String { return "https://www.googleapis.com/youtube/v3/subscriptions" }
    public override class var params: [String:String] { return ["mine": "true"] }
}

public class YouTubePlaylist: YouTubeResource {
    public override class var url: String { return "https://www.googleapis.com/youtube/v3/subscriptions" }
    public override class var params: [String:String] { return ["mine": "true"] }
}

public class YouTubeTrack: YouTubeResource {
    public override class var url: String { return "https://www.googleapis.com/youtube/v3/subscriptions" }
    public override class var params: [String:String] { return ["mine": "true"] }
}
