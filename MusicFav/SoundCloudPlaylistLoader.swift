
//
//  SoundCloudPlaylistLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/22/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import SoundCloudKit
import ReactiveSwift
import MusicFeeder
import Breit

extension SoundCloudKit.Track {
    var thumbnailURLString: String {
        if let url = artworkUrl { return url }
        else                    { return user.avatarUrl }
    }
    func toTrack() -> MusicFeeder.Track {
        let track = MusicFeeder.Track(      id: "\(Provider.soundCloud.rawValue)/\(id)",
                                      provider: Provider.soundCloud,
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
        case `init`
        case fetching
        case normal
        case error
    }

    enum Event {
        case startLoading
        case completeLoading
        case failToLoad
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
        self.state                 = State.init
        let pipe                   = Signal<Event, NSError>.pipe()
        signal                     = pipe.0
        observer                   = pipe.1
        playlistsDisposable        = nil
        hasNextPlaylists           = true
        favoritesDisposable        = nil
        hasNextFavorites           = true
    }

    fileprivate func fetchNextPlaylists() -> SignalProducer<Void, NSError> {
        state = State.fetching
        observer.send(value: .startLoading)
        return APIClient.sharedInstance.fetchPlaylistsOf(user).map {
            self.hasNextPlaylists = false
            self.playlists.append(contentsOf: $0)
            self.observer.send(value: .completeLoading)
            self.state = State.normal
        }.mapError {
            self.hasNextPlaylists = true
            self.observer.send(error: $0)
            self.state = State.error
            return $0
        }
    }

    func needFetchPlaylists() -> Bool {
        return hasNextPlaylists
    }

    func fetchPlaylists() {
        if !needFetchPlaylists() { return }
        switch state {
        case .init:     playlistsDisposable = fetchNextPlaylists().start()
        case .fetching: break
        case .normal:   playlistsDisposable = fetchNextPlaylists().start()
        case .error:    playlistsDisposable = fetchNextPlaylists().start()
        }
    }

    fileprivate func fetchNextFavorites() -> SignalProducer<Void, NSError> {
        state = State.fetching
        observer.send(value: .startLoading)
        return APIClient.sharedInstance.fetchFavoritesOf(user)
            .map {
                self.hasNextFavorites = false
                self.favorites.append(contentsOf: $0)
                self.observer.send(value: .completeLoading)
                self.state = State.normal
                self.fetchPlaylists()
            }.mapError {
                self.hasNextFavorites = true
                self.observer.send(error: $0)
                self.state = State.error
                return $0
        }
    }

    func needFetchFavorites() -> Bool {
        return hasNextFavorites
    }

    func fetchFavorites() {
        switch state {
        case .init:     playlistsDisposable = fetchNextFavorites().start()
        case .fetching: break
        case .normal:   playlistsDisposable = fetchNextFavorites().start()
        case .error:    playlistsDisposable = fetchNextFavorites().start()
        }
    }
}
