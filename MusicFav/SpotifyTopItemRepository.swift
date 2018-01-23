//
//  SpotifyTopItemRepository.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2018/01/22.
//  Copyright © 2018 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import MusicFeeder
import FeedlyKit
import Spotify
import ReactiveSwift
import Result

open class SpotifyTopItemRepository {
    public enum State {
        case normal
        case fetching
        case complete
        case error
    }

    public enum Event {
        case startLoadingLatest
        case completeLoadingLatest
        case startLoadingNext
        case completeLoadingNext
        case failToLoadNext
        case failToLoadLatest
    }

    let limit = 10

    open var tracks:        [SPTTrack]
    open var playlistQueue: PlaylistQueue
    open var state:         State
    open var signal:        Signal<Event, NSError>
    open var observer:      Signal<Event, NSError>.Observer
    open var hasNextPage:   Bool
    open var offset:        Int

    public init() {
        state            = .normal
        playlistQueue    = PlaylistQueue(playlists: [])
        hasNextPage      = true
        offset           = 0
        tracks           = []
        let pipe         = Signal<Event, NSError>.pipe()
        signal           = pipe.0
        observer         = pipe.1
    }

    deinit {
        dispose()
    }

    open func dispose() {
    }

    open func fetchLatestItems() {
        if state != .normal {
            return
        }
        state = .fetching
        observer.send(value: .startLoadingLatest)
        let _ = SpotifyAPIClient.shared.fetchTopTracks(0, limit: 20, timeRange: PersonalizeTimeRange.longTerm)
            .start(on: UIScheduler())
            .on(failed: {_ in
                self.state = State.error
                self.observer.send(value: .failToLoadNext)
            }, completed: {
            }, value: { page in
                self.hasNextPage = page.hasNextPage
                guard let tracks = page.tracksForPlayback() as? [SPTTrack] else { return }
                self.tracks = tracks
                self.playlistQueue = PlaylistQueue(playlists: [])
                tracks.forEach {
                    self.playlistQueue.enqueue(Playlist(id: $0.uri.absoluteString, title: $0.name, tracks: [MusicFeeder.Track(spotifyTrack: $0)]))
                }
                self.observer.send(value: .completeLoadingNext)
            }).start()
    }

    open func needNext() -> Bool {
        return hasNextPage
    }

    open func fetchItems() {
        if !needNext() { return }
        if state != .normal {
            return
        }
        state = .fetching
        observer.send(value: .startLoadingNext)
        SpotifyAPIClient.shared.fetchTopTracks(offset, limit: limit, timeRange: PersonalizeTimeRange.longTerm)
            .start(on: UIScheduler())
            .on(failed: {_ in
                self.state = State.error
                self.observer.send(value: .failToLoadNext)
            }, completed: {
            }, value: { page in
                self.hasNextPage = page.hasNextPage
                self.offset += self.limit
                guard let tracks = page.tracksForPlayback() as? [SPTTrack] else { return }
                self.tracks.append(contentsOf: tracks)
                tracks.forEach {
                    self.playlistQueue.enqueue(Playlist(id: $0.uri.absoluteString, title: $0.name, tracks: [MusicFeeder.Track(spotifyTrack: $0)]))
                }
                self.observer.send(value: .completeLoadingNext)
                if !page.hasNextPage {
                    self.state = .complete
                } else {
                    self.state = .normal
                }
            }).start()
    }
}
