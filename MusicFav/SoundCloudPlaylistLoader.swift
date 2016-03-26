//
//  SoundCloudPlaylistLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/22/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import SoundCloudKit
import ReactiveCocoa
import MusicFeeder
import Breit

extension SoundCloudKit.Track {
    var thumbnailURLString: String {
        if let url = artworkUrl { return url }
        else                    { return user.avatarUrl }
    }
    func toTrack() -> MusicFeeder.Track {
        let track = MusicFeeder.Track(      id: "\(Provider.SoundCloud.rawValue)/\(id)",
                                      provider: Provider.SoundCloud,
                                           url: uri,
                                    identifier: "\(id)",
                                         title: title)
        track.updateProperties(self)
        return track
    }
    func toPlaylist() -> MusicFeeder.Playlist {
        return MusicFeeder.Playlist(id: "soundcloud-track-\(id)",
                                 title: title,
                                tracks: [toTrack()])
    }
}

extension SoundCloudKit.Playlist {
    func toPlaylist() -> MusicFeeder.Playlist {
        return MusicFeeder.Playlist(id: "soundcloud-playlist-\(id)",
                                 title: title,
                                tracks: tracks.map { $0.toTrack() })
    }
}

class SoundCloudPlaylistLoader {
    enum State {
        case Init
        case Fetching
        case Normal
        case Error
    }

    enum Event {
        case StartLoading
        case CompleteLoading
        case FailToLoad
    }

    let user: User

    var playlists:      [SoundCloudKit.Playlist]
    var favorites:      [SoundCloudKit.Track]
    
    var state:          State
    var signal:         Signal<Event, NSError>
    var observer:       Signal<Event, NSError>.Observer
    
    var playlistsDisposable: Disposable?
    var hasNextPlaylists:    Bool

    var favoritesDisposable: Disposable?
    var hasNextFavorites:    Bool

    init(user: User) {
        self.user                  = user
        playlists                  = []
        favorites                  = []
        self.state                 = .Init
        let pipe                   = Signal<Event, NSError>.pipe()
        signal                     = pipe.0
        observer                   = pipe.1
        playlistsDisposable        = nil
        hasNextPlaylists           = true
        favoritesDisposable        = nil
        hasNextFavorites           = true
    }

    private func fetchNextPlaylists() -> SignalProducer<Void, NSError> {
        state = State.Fetching
        observer.sendNext(.StartLoading)
        return APIClient.sharedInstance.fetchPlaylistsOf(user).map {
            self.hasNextPlaylists = false
            self.playlists.appendContentsOf($0)
            self.observer.sendNext(.CompleteLoading)
            self.state = State.Normal
        }.mapError {
            self.hasNextPlaylists = true
            self.observer.sendFailed($0)
            self.state = State.Error
            return $0
        }
    }

    func needFetchPlaylists() -> Bool {
        return hasNextPlaylists
    }

    func fetchPlaylists() {
        if !needFetchPlaylists() { return }
        switch state {
        case .Init:     playlistsDisposable = fetchNextPlaylists().start()
        case .Fetching: break
        case .Normal:   playlistsDisposable = fetchNextPlaylists().start()
        case .Error:    playlistsDisposable = fetchNextPlaylists().start()
        }
    }

    private func fetchNextFavorites() -> SignalProducer<Void, NSError> {
        state = State.Fetching
        observer.sendNext(.StartLoading)
        return APIClient.sharedInstance.fetchFavoritesOf(user)
            .map {
                self.hasNextFavorites = false
                self.favorites.appendContentsOf($0)
                self.observer.sendNext(.CompleteLoading)
                self.state = State.Normal
                self.fetchPlaylists()
            }.mapError {
                self.hasNextFavorites = true
                self.observer.sendFailed($0)
                self.state = State.Error
                return $0
        }
    }

    func needFetchFavorites() -> Bool {
        return hasNextFavorites
    }

    func fetchFavorites() {
        switch state {
        case .Init:     playlistsDisposable = fetchNextFavorites().start()
        case .Fetching: break
        case .Normal:   playlistsDisposable = fetchNextFavorites().start()
        case .Error:    playlistsDisposable = fetchNextFavorites().start()
        }
    }
}