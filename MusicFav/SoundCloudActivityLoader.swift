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
import ReactiveCocoa
import Result

extension SoundCloudKit.Activity {
    func toPlaylist() -> MusicFeeder.Playlist {
        switch origin {
        case .Playlist(let playlist):
            return playlist.toPlaylist()
        case .Track(let track):
            return track.toPlaylist()
        }
    }
}

public class SoundCloudActivityLoader {
    public enum State {
        case Normal
        case Fetching
        case Complete
        case Error
    }

    public enum Event {
        case StartLoadingLatest
        case CompleteLoadingLatest
        case StartLoadingNext
        case CompleteLoadingNext
        case FailToLoadNext
        case FailToLoadLatest
    }

    public var activities:    [Activity]
    public var playlists:     [MusicFeeder.Playlist?]
    public var playlistQueue: PlaylistQueue
    public var state:         State
    public var signal:        Signal<Event, NSError>
    public var observer:      Signal<Event, NSError>.Observer

    var nextHref:   String? = ""
    var futureHref: String?

    public init() {
        state            = .Normal
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

    public func dispose() {
    }

    public func fetchLatestActivities() {
        if state != .Normal {
            return
        }
        state = .Fetching
        observer.sendNext(.StartLoadingLatest)
        var producer: SignalProducer<ActivityList, NSError>
        if let href = futureHref {
            producer = APIClient.sharedInstance.fetchLatestActivities(href)
        } else {
            producer = APIClient.sharedInstance.fetchActivities()
        }
        producer
            .startOn(UIScheduler())
            .on(
                next: { activityList in
                    self.activities.appendContentsOf(activityList.collection)
                    self.playlists.appendContentsOf(activityList.collection.map { $0.toPlaylist() })
                    self.nextHref   = activityList.nextHref
                    self.futureHref = activityList.futureHref
                },
                failed: { error in
                    SoundCloudKit.APIClient.handleError(error: error)
                    self.state = State.Error
                    self.observer.sendNext(.FailToLoadLatest)
                },
                completed: {
                    self.observer.sendNext(.CompleteLoadingLatest)
                    self.state = .Normal
            }).start()
    }

    public func needNext() -> Bool {
        return nextHref != nil
    }

    public func fetchActivities() {
        if !needNext() { return }
        if state != .Normal {
            return
        }
        state = .Fetching
        observer.sendNext(.StartLoadingNext)
        var producer: SignalProducer<ActivityList, NSError>
        let href = nextHref!
        if href.isEmpty {
            producer = APIClient.sharedInstance.fetchActivities()
        } else {
            producer = APIClient.sharedInstance.fetchNextActivities(href)
        }
        producer
            .startOn(UIScheduler())
            .on(
                next: { activityList in
                    for i in 0..<activityList.collection.count {
                        let activity = activityList.collection[i]
                        self.fetchPlaylist(activity).on(
                            next: { playlist in
                                self.activities.append(activity)
                                self.playlists.append(playlist)
                                self.playlistQueue.enqueue(playlist)
                                self.observer.sendNext(.CompleteLoadingNext)
                                return
                            }, failed: { e in
                            }, completed: {
                            }).start()
                    }
                    self.nextHref   = activityList.nextHref
                    self.futureHref = activityList.futureHref
                    self.observer.sendNext(.CompleteLoadingNext) // First reload tableView,
                    if activityList.nextHref == nil { // then wait for next load
                        self.state = .Complete
                    } else {
                        self.state = .Normal
                    }
                },
                failed: {error in
                    SoundCloudKit.APIClient.handleError(error: error)
                    self.state = State.Error
                    self.observer.sendNext(.FailToLoadNext)
                },
                completed: {
            }).start()
    }

    public func fetchPlaylist(activity: Activity) -> SignalProducer<MusicFeeder.Playlist, NSError> {
        switch activity.origin {
        case .Playlist(let playlist):
            return APIClient.sharedInstance.fetchPlaylist(playlist.id).map { $0.toPlaylist() }
        case .Track(let track):
            return SignalProducer(value: MusicFeeder.Playlist(id: "sc_track_\(track.id)", title: track.title, tracks: [track.toTrack()]))
        }
    }
}
