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
import YouTubeKit
import Spotify

enum TimelineItem {
    case entry(FeedlyKit.Entry)
    case activity(SoundCloudKit.Activity, MusicFeeder.Playlist?)
    case youTubePlaylist(YouTubeKit.PlaylistItem, MusicFeeder.Playlist?)
    case spotifyTopTrack(SPTTrack, MusicFeeder.Playlist?)
    case trackHistory(MusicFeeder.History, MusicFeeder.Playlist?)

    var entry: FeedlyKit.Entry? {
        switch self {
        case .entry(let entry):    return entry
        case .activity(_, _):      return nil
        case .youTubePlaylist(_):  return nil
        case .spotifyTopTrack(_):  return nil
        case .trackHistory(_):     return nil
        }
    }

    var playlist: MusicFeeder.Playlist? {
        switch self {
        case .entry(let entry):                 return entry.playlist
        case .activity(_, let playlist):        return playlist
        case .youTubePlaylist(_, let playlist): return playlist
        case .spotifyTopTrack(_, let playlist): return playlist
        case .trackHistory(_, let playlist):    return playlist
        }
    }

    var playlists: [ServicePlaylist] {
        switch self {
        case .entry(let entry): return entry.playlists
        case .activity:         return []
        case .youTubePlaylist:  return []
        case .spotifyTopTrack:  return []
        case .trackHistory:     return []
        }
    }

    var albums: [Album] {
        switch self {
        case .entry(let entry): return entry.albums
        case .activity:         return []
        case .youTubePlaylist:  return []
        case .spotifyTopTrack:  return []
        case .trackHistory:     return []
        }
    }

    var title: String? {
        switch self {
        case .entry(let entry):
            return entry.title
        case .activity(let activity, let playlist):
            switch activity.origin {
            case .playlist:         return playlist?.title ?? ""
            case .track(let track): return track.title
            }
        case .youTubePlaylist(let playlistItem, _): return playlistItem.title
        case .spotifyTopTrack(let track, _): return track.name
        case .trackHistory(_, let playlist): return playlist?.title
        }
    }
    var thumbnailURL: URL?  {
        switch self {
        case .entry(let entry):
            return entry.thumbnailURL ?? entry.playlistifiedEntry?.visualUrl
        case .activity(let activity, _):
            switch activity.origin {
            case .playlist(let playlist): return playlist.thumbnailURL
            case .track(let track):       return track.thumbnailURL
            }
        case .youTubePlaylist(let playlistItem, _): return playlistItem.thumbnailURL
        case .spotifyTopTrack(let track, _): return track.album?.largestCover?.imageURL
        case .trackHistory(_, let playlist): return playlist?.thumbnailUrl
        }
    }
    var description:  String? {
        switch self {
        case .entry(let entry):
            return entry.origin?.title
        case .activity(let activity, _):
            switch activity.origin {
            case .playlist(let playlist): return playlist.user.username
            case .track(let track):       return track.user.username
            }
        case .youTubePlaylist(let playlistItem, _):
            return playlistItem.description
        case .spotifyTopTrack(let track, _):
            return track.album?.name
        case .trackHistory(_, _):
            return nil
        }
    }

    var dateString:   String? {
        switch self {
        case .entry(let entry):
            return entry.published.date.elapsedTime
        case .activity(let activity, _):
            return activity.createdAt.toDate()!.elapsedTime
        case .youTubePlaylist(let playlistItem, _):
            return playlistItem.publishedAt?.toDate()?.elapsedTime
        case .spotifyTopTrack(let track, _):
            guard let artist = track.artists?.first as? SPTPartialArtist else { return nil }
            return artist.name
        case .trackHistory(let history, _):
            return history.timestamp.date.elapsedTime
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
        case .entry(let entry):
            return entry.playlistifiedEntry?.tracks.count
        case .activity(let activity, let playlist):
            switch activity.origin {
            case .playlist: return playlist?.tracks.count
            case .track:    return 1
            }
        case .youTubePlaylist:
            return 1
        case .spotifyTopTrack:
            return 1
        case .trackHistory:
            return 1
        }
    }
}
