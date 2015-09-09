//
//  Entity.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/30/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import MusicFeeder
import FeedlyKit
import SoundCloudKit

enum TimelineItem {
    case Entry(FeedlyKit.Entry, MusicFeeder.Playlist?)
    case Activity(SoundCloudKit.Activity, MusicFeeder.Playlist?)
    case YouTubePlaylist(YouTubePlaylistItem, MusicFeeder.Playlist?)

    var entry: FeedlyKit.Entry? {
        switch self {
        case .Entry(let entry, let playlist):       return entry
        case .Activity(let activity, let playlist): return nil
        case .YouTubePlaylist(let playlistItem):    return nil
        }
    }

    var playlist: MusicFeeder.Playlist? {
        switch self {
        case .Entry(let _, let playlist):           return playlist
        case .Activity(let _, let playlist):        return playlist
        case .YouTubePlaylist(let _, let playlist): return playlist
        }
    }

    var title: String? {
        switch self {
        case .Entry(let entry, let playlist):
            return entry.title ?? playlist?.title
        case .Activity(let activity, let playlist):
            switch activity.origin {
            case .Playlist:         return playlist?.title ?? ""
            case .Track(let track): return track.title
            }
        case .YouTubePlaylist(let playlistItem, let _): return playlistItem.title
        }
    }
    var thumbnailURL: NSURL?  {
        switch self {
        case .Entry(let entry, let playlist):
            return entry.thumbnailURL ?? playlist?.thumbnailUrl
        case .Activity(let activity, let playlist):
            switch activity.origin {
            case .Playlist(let playlist): return playlist.thumbnailURL
            case .Track(let track):       return track.thumbnailURL
            }
        case .YouTubePlaylist(let playlistItem, let _): return playlistItem.thumbnailURL
        }
    }
    var description:  String? {
        switch self {
        case .Entry(let entry, let playlist):
            return entry.origin?.title
        case .Activity(let activity, let playlist):
            switch activity.origin {
            case .Playlist(let playlist): return playlist.user.username
            case .Track(let track):       return track.user.username
            }
        case .YouTubePlaylist(let playlistItem, let _):
            return playlistItem.description
        }
    }

    var dateString:   String? {
        switch self {
        case .Entry(let entry, let playlist):
            return entry.passedTime
        case .Activity(let activity, let playlist):
            return activity.createdAt.toDate()!.elapsedTime
        case .YouTubePlaylist(let playlistItem, let _):
            return playlistItem.publishedAt?.toDate()?.elapsedTime
        }
    }

    var trackNumString: String {
        if let c = trackCount {
            return "\(c) tracks"
        } else {
            return "? tracks"
        }
    }

    var trackCount:   Int? {
        switch self {
        case .Entry(let entry, let playlist):
            return playlist?.tracks.count
        case .Activity(let activity, let playlist):
            switch activity.origin {
            case .Playlist: return playlist?.tracks.count
            case .Track:    return 1
            }
        case .YouTubePlaylist(let playlistItem):
            return 1
        }
    }
}