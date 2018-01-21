//
//  SpotifyPlaylistRepository.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2018/01/21.
//  Copyright © 2018 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import ReactiveSwift
import Spotify
import MusicFeeder
import Breit

class SpotifyPlaylistRepository {
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

    var playlists:      [SPTPartialPlaylist]
    
    var state:          State
    var signal:         Signal<Event, SpotifyError>
    var observer:       Signal<Event, SpotifyError>.Observer

    var playlistsDisposable: Disposable?
    var hasNextPlaylists:    Bool
    var currentPlaylistList: SPTPlaylistList?

    init() {
        playlists                  = []
        self.state                 = State.init
        let pipe                   = Signal<Event, SpotifyError>.pipe()
        signal                     = pipe.0
        observer                   = pipe.1
        playlistsDisposable        = nil
        hasNextPlaylists           = true
    }

    fileprivate func fetchNextPlaylists() -> SignalProducer<Void, SpotifyError> {
        state = State.fetching
        observer.send(value: .startLoading)

        var signal = SpotifyAPIClient.shared.fetchMyPlaylists()
        if let playlistList = currentPlaylistList {
            signal = SpotifyAPIClient.shared.playlistsOfNextPage(playlistList)
        }

        return signal.map {value in
            self.hasNextPlaylists = value.hasNextPage
            self.currentPlaylistList = value
            if let items = value.items {
                for item in items {
                    if let item = item as? SPTPartialPlaylist {
                        self.playlists.append(item)
                    }
                }
            }
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
}
