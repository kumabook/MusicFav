//
//  YouTubeActivityLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 9/5/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import MusicFeeder

class YouTubeActivityLoader {
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

    var itemsOfPlaylist:            [YouTubePlaylist: [YouTubePlaylistItem]]
    var playlistsOfYouTubePlaylist: [YouTubePlaylist: [Playlist]]
    var channels:                   [MyChannel]

    var state:          State
    var signal:         Signal<Event, NSError>
    var observer:       Signal<Event, NSError>.Observer

    var itemsPageTokenOfPlaylist:  [YouTubePlaylist: String]
    var itemsDisposableOfPlaylist: [YouTubePlaylist: Disposable?]
    var playlistQueue:             PlaylistQueue
    var channelsPageToken:         String?
    var channelsDisposable:        Disposable?

    init() {
        channels                   = []
        itemsOfPlaylist            = [:]
        playlistsOfYouTubePlaylist = [:]
        playlistQueue              = PlaylistQueue(playlists: [])
        self.state                 = .init
        let pipe                   = Signal<Event, NSError>.pipe()
        signal                     = pipe.0
        observer                   = pipe.1
        channelsPageToken          = ""
        itemsPageTokenOfPlaylist   = [:]
        itemsDisposableOfPlaylist  = [:]
    }

    func clear() {
        channelsDisposable?.dispose()
        channelsDisposable = nil
        for disposable in itemsDisposableOfPlaylist.values {
            disposable?.dispose()
        }
        channels                   = []
        itemsOfPlaylist            = [:]
        playlistsOfYouTubePlaylist = [:]
        playlistQueue              = PlaylistQueue(playlists: [])
        state                      = .normal
        channelsPageToken          = ""
        itemsPageTokenOfPlaylist   = [:]
        itemsDisposableOfPlaylist  = [:]
    }

    func clearPlaylist(_ playlist: YouTubePlaylist) {
        itemsDisposableOfPlaylist[playlist]??.dispose()
        itemsDisposableOfPlaylist[playlist]  = nil
        itemsPageTokenOfPlaylist[playlist]   = ""
    }

    func needFetchChannels() -> Bool {
        return channelsPageToken != nil
    }

    func fetchChannels() {
        if !needFetchChannels() { return }
        switch state {
        case .init:     channelsDisposable = fetchNextChannels().start()
        case .fetching: break
        case .normal:   channelsDisposable = fetchNextChannels().start()
        case .error:    channelsDisposable = fetchNextChannels().start()
        }
    }

    fileprivate func fetchNextChannels() -> SignalProducer<Void, NSError> {
        state = State.fetching
        observer.send(value: .startLoading)
        return YouTubeAPIClient.sharedInstance.fetchMyChannels(channelsPageToken).map {
            self.channels.append(contentsOf: $0.items)
            self.channelsPageToken = $0.nextPageToken
            if self.channels.count > 0 {
                for key in self.channels[0].relatedPlaylists.keys {
                    let id = self.channels[0].relatedPlaylists[key]!
                    let playlist = YouTubePlaylist(id: id, title: key)
                    self.itemsOfPlaylist[playlist]            = []
                    self.itemsPageTokenOfPlaylist[playlist]   = ""
                    self.playlistsOfYouTubePlaylist[playlist] = []
                    self.fetchNextPlaylistItems(playlist).start()
                }
            }
            self.observer.send(value: .completeLoading)
            self.state = State.normal
        }
    }

    func needFetchPlaylistItems(_ playlist: YouTubePlaylist) -> Bool {
        return itemsPageTokenOfPlaylist[playlist] != nil
    }

    func fetchPlaylistItems(_ playlist: YouTubePlaylist) {
        if !needFetchPlaylistItems(playlist) { return }
        switch state {
        case .init:     itemsDisposableOfPlaylist[playlist] = fetchNextPlaylistItems(playlist).start()
        case .fetching: break
        case .normal:   itemsDisposableOfPlaylist[playlist] = fetchNextPlaylistItems(playlist).start()
        case .error:    itemsDisposableOfPlaylist[playlist] = fetchNextPlaylistItems(playlist).start()
        }
    }

    fileprivate func fetchNextPlaylistItems(_ playlist: YouTubePlaylist) -> SignalProducer<Void, NSError> {
        state = State.fetching
        observer.send(value: .startLoading)
        let pageToken = itemsPageTokenOfPlaylist[playlist]
        return YouTubeAPIClient.sharedInstance.fetchPlaylistItems(playlist.id, pageToken: pageToken).map {
            if self.itemsPageTokenOfPlaylist[playlist] == "" {
                self.itemsOfPlaylist[playlist]            = []
                self.playlistsOfYouTubePlaylist[playlist] = []
            }
            self.itemsPageTokenOfPlaylist[playlist] = $0.nextPageToken
            for item in $0.items {
                let p = item.toPlaylist()
                self.itemsOfPlaylist[playlist]?.append(item)
                self.playlistsOfYouTubePlaylist[playlist]?.append(p)
                self.playlistQueue.enqueue(p)
                item.track.fetchPropertiesFromProviderIfNeed()
                    .on(
                        value: { track in
                            self.playlistQueue.trackUpdated(track)
                            p.observer.send(value: PlaylistEvent.load(index: 0))
                        },
                        failed: { error in },
                        completed: {}
                    ).start()
            }
            self.observer.send(value: .completeLoading)
            self.state = State.normal
        }
    }
}
