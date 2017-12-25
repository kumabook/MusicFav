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

open class YouTubePlaylist: YouTubeResource, Hashable, Equatable {
    open class var url: String { return "https://www.googleapis.com/youtube/v3/playlists" }
    open class var params: [String:String] { return ["mine": "true"] }
    open var hashValue: Int { return id.hashValue }
    open let etag:        String
    open let id:          String
    open let kind:        String
    open let title:       String!
    open let description: String!
    open let publishedAt: String?
    open let thumbnails:  [String:String]
    open let resourceId:  [String:String]

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

    open var thumbnailURL: URL? {
             if let url = thumbnails["default"] { return URL(string: url) }
        else if let url = thumbnails["medium"]  { return URL(string: url) }
        else if let url = thumbnails["high"]    { return URL(string: url) }
        else                                    { return nil }
    }
}

public func ==(lhs: YouTubePlaylist, rhs: YouTubePlaylist) -> Bool {
    return lhs.id == rhs.id
}

open class YouTubePlaylistItem: YouTubeResource, Hashable, Equatable {
    open class var url: String { return "https://www.googleapis.com/youtube/v3/playlistItems" }
    open class var params: [String:String] { return [:] }
    open let etag:        String
    open let id:          String
    open let kind:        String
    open let title:       String!
    open let description: String!
    open let publishedAt: String?
    open let thumbnails: [String:String]
    open let resourceId: [String:String]

    open let position:      UInt
    open let videoId:       String
    open let startAt:       String?
    open let endAt:         String?
    open let note:          String?
    open let privacyStatus: String?

    open var track:         Track

    open var hashValue: Int { return id.hashValue }

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

        track              = Track(      id: "\(Provider.youTube.rawValue)/\(videoId)",
                                   provider: Provider.youTube,
                                        url: "https://www.youtube.com/watch?v=\(videoId)",
                                 identifier: videoId,
                                      title: title)
    }

    open var thumbnailURL: URL? {
        if let url = thumbnails["default"] { return URL(string: url) }
        else if let url = thumbnails["medium"] { return URL(string: url) }
        else if let url = thumbnails["high"]   { return URL(string: url) }
        else                                   { return nil }
    }

    func toPlaylist() -> MusicFeeder.Playlist {
        return MusicFeeder.Playlist(id: "youtube-track-\(id)",
                                 title: title,
                                tracks: [track])
    }
}

public func ==(lhs: YouTubePlaylistItem, rhs: YouTubePlaylistItem) -> Bool {
    return lhs.id == rhs.id
}
