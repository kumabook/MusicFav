//
//  SoundCloudActivityLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/26/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import MusicFeeder
import FeedlyKit
import SoundCloudKit
import ReactiveSwift
import Result

extension SoundCloudKit.Activity {
    func toPlaylist() -> MusicFeeder.Playlist {
        switch origin {
        case .playlist(let playlist):
            return playlist.toPlaylist()
        case .track(let track):
            return track.toPlaylist()
        }
    }
}

open class SoundCloudActivityLoader {
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

    open var activities:    [Activity]
    open var playlists:     [MusicFeeder.Playlist?]
    open var playlistQueue: PlaylistQueue
    open var state:         State
    open var signal:        Signal<Event, NSError>
    open var observer:      Signal<Event, NSError>.Observer

    var nextHref:   String? = ""
    var futureHref: String?

    public init() {
        state            = .normal
        activities       = []
        playlists        = []
        playlistQueue    = PlaylistQueue(playlists: [])
        let pipe         = Signal<Event, NSError>.pipe()
        signal           = pipe.0
        observer         = pipe.1
    }

    deinit {
        dispose()
    }

    open func dispose() {
    }

    open func fetchLatestActivities() {
        if state != .normal {
            return
        }
        state = .fetching
        observer.send(value: .startLoadingLatest)
        var producer: SignalProducer<ActivityList, NSError>
        if let href = futureHref {
            producer = APIClient.shared.fetchLatestActivities(href)
        } else {
            producer = APIClient.shared.fetchActivities()
        }
        producer
            .start(on: UIScheduler())
            .on(
                failed: { error in
                    SoundCloudKit.APIClient.handleError(error)
                    self.state = State.error
                    self.observer.send(value: .failToLoadLatest)
            },
                completed: {
                    self.observer.send(value: .completeLoadingLatest)
                    self.state = .normal
            },
                value: { activityList in
                    self.activities.append(contentsOf: activityList.collection)
                    self.playlists.append(contentsOf: activityList.collection.map { $0.toPlaylist() })
                    self.nextHref   = activityList.nextHref
                    self.futureHref = activityList.futureHref
            }).start()
    }

    open func needNext() -> Bool {
        return nextHref != nil
    }

    open func fetchActivities() {
        if !needNext() { return }
        if state != .normal {
            return
        }
        state = .fetching
        observer.send(value: .startLoadingNext)
        var producer: SignalProducer<ActivityList, NSError>
        let href = nextHref!
        if href.isEmpty {
            producer = APIClient.shared.fetchActivities()
        } else {
            producer = APIClient.shared.fetchNextActivities(href)
        }
        producer
            .start(on: UIScheduler())
            .on(
                failed: {error in
                    SoundCloudKit.APIClient.handleError(error)
                    self.state = State.error
                    self.observer.send(value: .failToLoadNext)
            },
                completed: {
            },
                value: { activityList in
                    for i in 0..<activityList.collection.count {
                        let activity = activityList.collection[i]
                        self.fetchPlaylist(activity).on(
                            failed: { e in
                        }, completed: {
                        }, value: { playlist in
                            self.activities.append(activity)
                            self.playlists.append(playlist)
                            self.playlistQueue.enqueue(playlist)
                            self.observer.send(value: .completeLoadingNext)
                            return
                        }).start()
                    }
                    self.nextHref   = activityList.nextHref
                    self.futureHref = activityList.futureHref
                    self.observer.send(value: .completeLoadingNext) // First reload tableView,
                    if activityList.nextHref == nil { // then wait for next load
                        self.state = .complete
                    } else {
                        self.state = .normal
                    }
            }).start()
    }

    open func fetchPlaylist(_ activity: Activity) -> SignalProducer<MusicFeeder.Playlist, NSError> {
        switch activity.origin {
        case .playlist(let playlist):
            return APIClient.shared.fetchPlaylist(playlist.id).map { $0.toPlaylist() }
        case .track(let track):
            return SignalProducer(value: MusicFeeder.Playlist(id: "sc_track_\(track.id)", title: track.title, tracks: [track.toTrack()]))
        }
    }
}
