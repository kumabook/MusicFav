//
//  YouTubePlaylistLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/18/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import ReactiveCocoa
import Result

class YouTubePlaylistLoader {
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
        self.state         = .Init
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
        state              = .Normal
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
        case .Init:     playlistsDisposable = fetchNextPlaylists().start()
        case .Fetching: break
        case .Normal:   playlistsDisposable = fetchNextPlaylists().start()
        case .Error:    playlistsDisposable = fetchNextPlaylists().start()
        }
    }

    func needFetchPlaylistItems(playlist: YouTubePlaylist) -> Bool {
        return itemsPageTokenOfPlaylist[playlist] != nil
    }

    func fetchPlaylistItems(playlist: YouTubePlaylist) {
        if !needFetchPlaylistItems(playlist) { return }
        switch state {
        case .Init:     playlistsDisposable = fetchNextPlaylistItems(playlist).start()
        case .Fetching: break
        case .Normal:   playlistsDisposable = fetchNextPlaylistItems(playlist).start()
        case .Error:    playlistsDisposable = fetchNextPlaylistItems(playlist).start()
        }
    }

    private func fetchNextPlaylists() -> SignalProducer<Void, NSError> {
        state = State.Fetching
        observer.sendNext(.StartLoading)
        return YouTubeAPIClient.sharedInstance.fetchPlaylists(playlistsPageToken).map {
            self.playlists.appendContentsOf($0.items)
            self.playlistsPageToken = $0.nextPageToken
            for i in $0.items {
                self.itemsOfPlaylist[i]          = []
                self.itemsPageTokenOfPlaylist[i] = ""
            }
            self.observer.sendNext(.CompleteLoading)
            self.state = State.Normal
        }
    }

    private func fetchNextPlaylistItems(playlist: YouTubePlaylist) -> SignalProducer<Void, NSError> {
        state = State.Fetching
        observer.sendNext(.StartLoading)
        let pageToken = itemsPageTokenOfPlaylist[playlist]!
        return YouTubeAPIClient.sharedInstance.fetchPlaylistItems(playlist, pageToken: pageToken).map {
            self.itemsOfPlaylist[playlist]?.appendContentsOf($0.items)
            self.itemsPageTokenOfPlaylist[playlist] = $0.nextPageToken
            self.observer.sendNext(.CompleteLoading)
            self.state = State.Normal
        }
    }
}