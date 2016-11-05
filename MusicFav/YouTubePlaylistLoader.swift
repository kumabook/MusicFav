//
//  YouTubePlaylistLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/18/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result

class YouTubePlaylistLoader {
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

    var playlists:       [YouTubePlaylist]
    var itemsOfPlaylist: [YouTubePlaylist: [YouTubePlaylistItem]]

    var state:          State
    var signal:         Signal<Event, NSError>
    var observer:       Signal<Event, NSError>.Observer

    var playlistsPageToken:  String?
    var playlistsDisposable: Disposable?

    var itemsPageTokenOfPlaylist:  [YouTubePlaylist: String]
    var itemsDisposableOfPlaylist: [YouTubePlaylist: Disposable?]

    init() {
        playlists          = []
        itemsOfPlaylist    = [:]
        self.state         = .init
        let pipe           = Signal<Event, NSError>.pipe()
        signal             = pipe.0
        observer           = pipe.1
        playlistsPageToken = ""
        itemsPageTokenOfPlaylist  = [:]
        itemsDisposableOfPlaylist = [:]
    }

    func clear() {
        playlists          = []
        itemsOfPlaylist    = [:]
        playlistsPageToken = ""
        state              = .normal
        playlistsDisposable?.dispose()
        itemsPageTokenOfPlaylist  = [:]
        itemsDisposableOfPlaylist = [:]
    }

    func needFetchPlaylists() -> Bool {
        return playlistsPageToken != nil
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

    func needFetchPlaylistItems(_ playlist: YouTubePlaylist) -> Bool {
        return itemsPageTokenOfPlaylist[playlist] != nil
    }

    func fetchPlaylistItems(_ playlist: YouTubePlaylist) {
        if !needFetchPlaylistItems(playlist) { return }
        switch state {
        case .init:     playlistsDisposable = fetchNextPlaylistItems(playlist).start()
        case .fetching: break
        case .normal:   playlistsDisposable = fetchNextPlaylistItems(playlist).start()
        case .error:    playlistsDisposable = fetchNextPlaylistItems(playlist).start()
        }
    }

    fileprivate func fetchNextPlaylists() -> SignalProducer<Void, NSError> {
        state = State.fetching
        observer.send(value: .startLoading)
        return YouTubeAPIClient.sharedInstance.fetchPlaylists(playlistsPageToken).map {
            self.playlists.append(contentsOf: $0.items)
            self.playlistsPageToken = $0.nextPageToken
            for i in $0.items {
                self.itemsOfPlaylist[i]          = []
                self.itemsPageTokenOfPlaylist[i] = ""
            }
            self.observer.send(value: .completeLoading)
            self.state = State.normal
        }
    }

    fileprivate func fetchNextPlaylistItems(_ playlist: YouTubePlaylist) -> SignalProducer<Void, NSError> {
        state = State.fetching
        observer.send(value: .startLoading)
        let pageToken = itemsPageTokenOfPlaylist[playlist]!
        return YouTubeAPIClient.sharedInstance.fetchPlaylistItems(playlist, pageToken: pageToken).map {
            self.itemsOfPlaylist[playlist]?.append(contentsOf: $0.items)
            self.itemsPageTokenOfPlaylist[playlist] = $0.nextPageToken
            self.observer.send(value: .completeLoading)
            self.state = State.normal
        }
    }
}
