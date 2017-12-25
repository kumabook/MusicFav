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
    case entry(FeedlyKit.Entry, MusicFeeder.Playlist?)
    case activity(SoundCloudKit.Activity, MusicFeeder.Playlist?)
    case youTubePlaylist(YouTubePlaylistItem, MusicFeeder.Playlist?)
    case trackHistory(MusicFeeder.History, MusicFeeder.Playlist?)

    var entry: FeedlyKit.Entry? {
        switch self {
        case .entry(let entry, _): return entry
        case .activity(_, _):      return nil
        case .youTubePlaylist(_):  return nil
        case .trackHistory(_):     return nil
        }
    }

    var playlist: MusicFeeder.Playlist? {
        switch self {
        case .entry(_, let playlist):           return playlist
        case .activity(_, let playlist):        return playlist
        case .youTubePlaylist(_, let playlist): return playlist
        case .trackHistory(_, let playlist):    return playlist
        }
    }

    var title: String? {
        switch self {
        case .entry(let entry, let playlist):
            return entry.title ?? playlist?.title
        case .activity(let activity, let playlist):
            switch activity.origin {
            case .playlist:         return playlist?.title ?? ""
            case .track(let track): return track.title
            }
        case .youTubePlaylist(let playlistItem, _): return playlistItem.title
        case .trackHistory(_, let playlist): return playlist?.title
        }
    }
    var thumbnailURL: URL?  {
        switch self {
        case .entry(let entry, let playlist):
            return entry.thumbnailURL ?? playlist?.thumbnailUrl
        case .activity(let activity, _):
            switch activity.origin {
            case .playlist(let playlist): return playlist.thumbnailURL
            case .track(let track):       return track.thumbnailURL
            }
        case .youTubePlaylist(let playlistItem, _): return playlistItem.thumbnailURL
        case .trackHistory(_, let playlist): return playlist?.thumbnailUrl
        }
    }
    var description:  String? {
        switch self {
        case .entry(let entry, _):
            return entry.origin?.title
        case .activity(let activity, _):
            switch activity.origin {
            case .playlist(let playlist): return playlist.user.username
            case .track(let track):       return track.user.username
            }
        case .youTubePlaylist(let playlistItem, _):
            return playlistItem.description
        case .trackHistory(_, _): return nil
        }
    }

    var dateString:   String? {
        switch self {
        case .entry(let entry, _):
            return entry.published.date.elapsedTime
        case .activity(let activity, _):
            return activity.createdAt.toDate()!.elapsedTime
        case .youTubePlaylist(let playlistItem, _):
            return playlistItem.publishedAt?.toDate()?.elapsedTime
        case .trackHistory(let history, _): return history.timestamp.date.elapsedTime
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
        case .entry(_, let playlist):
            return playlist?.tracks.count
        case .activity(let activity, let playlist):
            switch activity.origin {
            case .playlist: return playlist?.tracks.count
            case .track:    return 1
            }
        case .youTubePlaylist:
            return 1
        case .trackHistory(_, _): return 1
        }
    }
}
