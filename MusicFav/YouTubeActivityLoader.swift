//
//  YouTubeActivityLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 9/5/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import ReactiveCocoa
import Result
import MusicFeeder

class YouTubeActivityLoader {
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

    var itemsOfPlaylist:            [YouTubePlaylist: [YouTubePlaylistItem]]
    var playlistsOfYouTubePlaylist: [YouTubePlaylist: [Playlist]]
    var channels:                   [MyChannel]

    var state:          State
    var signal:         Signal<Event, NSError>
    var observer:       Signal<Event, NSError>.Observer

    var itemsPageTokenOfPlaylist:  [YouTubePlaylist: String]
    var itemsDisposableOfPlaylist: [YouTubePlaylist: Disposable?]
    var channelsPageToken:         String?
    var channelsDisposable:        Disposable?

    init() {
        channels                   = []
        itemsOfPlaylist            = [:]
        playlistsOfYouTubePlaylist = [:]
        self.state                 = .Init
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
        state                      = .Normal
        channelsPageToken          = ""
        itemsPageTokenOfPlaylist   = [:]
        itemsDisposableOfPlaylist  = [:]
    }

    func clearPlaylist(playlist: YouTubePlaylist) {
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
        case .Init:     channelsDisposable = fetchNextChannels().start()
        case .Fetching: break
        case .Normal:   channelsDisposable = fetchNextChannels().start()
        case .Error:    channelsDisposable = fetchNextChannels().start()
        }
    }

    private func fetchNextChannels() -> SignalProducer<Void, NSError> {
        state = State.Fetching
        observer.sendNext(.StartLoading)
        return YouTubeAPIClient.sharedInstance.fetchMyChannels(channelsPageToken).map {
            self.channels.appendContentsOf($0.items)
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
            self.observer.sendNext(.CompleteLoading)
            self.state = State.Normal
        }
    }

    func needFetchPlaylistItems(playlist: YouTubePlaylist) -> Bool {
        return itemsPageTokenOfPlaylist[playlist] != nil
    }

    func fetchPlaylistItems(playlist: YouTubePlaylist) {
        if !needFetchPlaylistItems(playlist) { return }
        switch state {
        case .Init:     itemsDisposableOfPlaylist[playlist] = fetchNextPlaylistItems(playlist).start()
        case .Fetching: break
        case .Normal:   itemsDisposableOfPlaylist[playlist] = fetchNextPlaylistItems(playlist).start()
        case .Error:    itemsDisposableOfPlaylist[playlist] = fetchNextPlaylistItems(playlist).start()
        }
    }

    private func fetchNextPlaylistItems(playlist: YouTubePlaylist) -> SignalProducer<Void, NSError> {
        state = State.Fetching
        observer.sendNext(.StartLoading)
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
                item.track.fetchPropertiesFromProvider(false)
                    .on(
                        next: { item in p.observer.sendNext(PlaylistEvent.Load(index: 0))},
                        failed: { error in },
                        completed: {}
                    ).start()
            }
            self.observer.sendNext(.CompleteLoading)
            self.state = State.Normal
        }
    }
}