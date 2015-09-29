//
//  YouTubePlaylist.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/18/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import SwiftyJSON
import MusicFeeder

public class YouTubePlaylist: YouTubeResource, Hashable, Equatable {
    public class var url: String { return "https://www.googleapis.com/youtube/v3/playlists" }
    public class var params: [String:String] { return ["mine": "true"] }
    public var hashValue: Int { return id.hashValue }
    public let etag:        String
    public let id:          String
    public let kind:        String
    public let title:       String!
    public let description: String!
    public let publishedAt: String?
    public let thumbnails:  [String:String]
    public let resourceId:  [String:String]

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
    }

    public init(id: String, title: String) {
        self.etag        = id
        self.id          = id
        self.kind        = "playlistItem"
        self.title       = title
        self.description = title
        self.publishedAt = nil
        self.thumbnails  = [:]
        self.resourceId  = [:]
    }

    public var thumbnailURL: NSURL? {
             if let url = thumbnails["default"] { return NSURL(string: url) }
        else if let url = thumbnails["medium"]  { return NSURL(string: url) }
        else if let url = thumbnails["high"]    { return NSURL(string: url) }
        else                                    { return nil }
    }
}

public func ==(lhs: YouTubePlaylist, rhs: YouTubePlaylist) -> Bool {
    return lhs.id == rhs.id
}

public class YouTubePlaylistItem: YouTubeResource {
    public class var url: String { return "https://www.googleapis.com/youtube/v3/playlistItems" }
    public class var params: [String:String] { return [:] }
    public let etag:        String
    public let id:          String
    public let kind:        String
    public let title:       String!
    public let description: String!
    public let publishedAt: String?
    public let thumbnails: [String:String]
    public let resourceId: [String:String]

    public let position:      UInt
    public let videoId:       String
    public let startAt:       String?
    public let endAt:         String?
    public let note:          String?
    public let privacyStatus: String?

    public var track:         Track

    public required init(json: JSON) {
        let snippet        = json["snippet"].dictionaryValue
        let contentDetails = json["contentDetails"].dictionaryValue
        let status         = json["status"].dictionaryValue
        etag               = json["etag"].stringValue
        id                 = json["id"].stringValue
        kind               = json["kind"].stringValue
        title              = snippet["title"]!.stringValue
        description        = snippet["description"]!.stringValue
        publishedAt        = snippet["publishedAt"]?.string
        thumbnails         = ChannelResource.thumbnails(snippet)
        resourceId         = ChannelResource.resourceId(snippet)

        position           = snippet["position"]!.uIntValue
        videoId            = contentDetails["videoId"]!.stringValue
        startAt            = contentDetails["startAt"]?.stringValue
        endAt              = contentDetails["endAt"]?.stringValue
        note               = contentDetails["note"]?.stringValue
        privacyStatus      = status["privacyStatus"]?.stringValue

        track              = Track(provider: Provider.YouTube,
                                        url: "https://www.youtube.com/watch?v=\(videoId)",
                                 identifier: videoId,
                                      title: title)
    }

    public var thumbnailURL: NSURL? {
        if let url = thumbnails["default"] { return NSURL(string: url) }
        else if let url = thumbnails["medium"] { return NSURL(string: url) }
        else if let url = thumbnails["high"]   { return NSURL(string: url) }
        else                                   { return nil }
    }

    func toPlaylist() -> MusicFeeder.Playlist {
        return MusicFeeder.Playlist(id: "youtube-track-\(id)",
                                 title: title,
                                tracks: [track])
    }
}