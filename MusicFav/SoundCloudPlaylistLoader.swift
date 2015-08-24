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
import Box
import MusicFeeder
import Breit

extension SoundCloudKit.Track {
    var thumbnailURLString: String {
        if let url = artworkUrl {
            return url
        }
        return user.avatarUrl
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
    var sink:           SinkOf<ReactiveCocoa.Event<Event, NSError>>
    
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
        sink                       = pipe.1
        playlistsDisposable        = nil
        hasNextPlaylists           = true
        favoritesDisposable        = nil
        hasNextFavorites           = true
    }

    private func fetchNextPlaylists() -> SignalProducer<Void, NSError> {
        state = State.Fetching
        sink.put(ReactiveCocoa.Event<Event, NSError>.Next(Box(.StartLoading)))
        return APIClient.sharedInstance.fetchPlaylistsOf(user) |> map {
            self.hasNextPlaylists = false
            self.playlists.extend($0)
            self.sink.put(ReactiveCocoa.Event<Event, NSError>.Next(Box(.CompleteLoading)))
            self.state = State.Normal
        } |> mapError {
            self.hasNextPlaylists = true
            self.sink.put(ReactiveCocoa.Event<Event, NSError>.Error(Box($0)))
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
        sink.put(ReactiveCocoa.Event<Event, NSError>.Next(Box(.StartLoading)))
        return APIClient.sharedInstance.fetchFavoritesOf(user)
            |> map {
                self.hasNextFavorites = false
                self.favorites.extend($0)
                self.sink.put(ReactiveCocoa.Event<Event, NSError>.Next(Box(.CompleteLoading)))
                self.state = State.Normal
                self.fetchPlaylists()
            } |> mapError {
                self.hasNextFavorites = true
                self.sink.put(ReactiveCocoa.Event<Event, NSError>.Error(Box($0)))
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