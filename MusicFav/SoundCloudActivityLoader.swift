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
import Box

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

    public var activities: [Activity]
    public var playlists:  [MusicFeeder.Playlist?]
    public var state:      State
    public var signal:     Signal<Event, NSError>
    public var sink:       SinkOf<ReactiveCocoa.Event<Event, NSError>>

    var nextHref:   String? = ""
    var futureHref: String?

    public init() {
        state            = .Normal
        activities       = []
        playlists        = []
        let pipe         = Signal<Event, NSError>.pipe()
        signal           = pipe.0
        sink             = pipe.1
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
        sink.put(.Next(Box(.StartLoadingLatest)))
        var producer: SignalProducer<ActivityList, NSError>
        if let href = futureHref {
            producer = APIClient.sharedInstance.fetchLatestActivities(href)
        } else {
            producer = APIClient.sharedInstance.fetchActivities()
        }
        producer |> startOn(UIScheduler())
            |> start(
                next: { activityList in
                    self.activities.extend(activityList.collection)
                    self.playlists.extend(activityList.collection.map { $0.toPlaylist() })
                    self.nextHref   = activityList.nextHref
                    self.futureHref = activityList.futureHref
                },
                error: { error in
                    CloudAPIClient.handleError(error: error)
                    self.state = State.Error
                    self.sink.put(.Next(Box(.FailToLoadLatest)))
                },
                completed: {
                    self.sink.put(.Next(Box(.CompleteLoadingLatest)))
                    self.state = .Normal
            })
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
        sink.put(.Next(Box(.StartLoadingNext)))
        var producer: SignalProducer<ActivityList, NSError>
        let href = nextHref!
        if href.isEmpty {
            producer = APIClient.sharedInstance.fetchActivities()
        } else {
            producer = APIClient.sharedInstance.fetchNextActivities(href)
        }
        producer |> startOn(UIScheduler())
            |> start(
                next: { activityList in
                    for i in 0..<activityList.collection.count {
                        let activity = activityList.collection[i]
                        self.activities.append(activity)
                        self.playlists.append(activity.toPlaylist())
                        self.fetchPlaylist(activity).start(
                            next: { playlist in
                                self.playlists[i] = playlist.toPlaylist()
                                return
                            }, error: { e in
                            }, completed: {
                            })
                    }
                    self.nextHref   = activityList.nextHref
                    self.futureHref = activityList.futureHref
                    self.sink.put(.Next(Box(.CompleteLoadingNext))) // First reload tableView,
                    if activityList.nextHref == nil { // then wait for next load
                        self.state = .Complete
                    } else {
                        self.state = .Normal
                    }
                },
                error: {error in
                    CloudAPIClient.handleError(error: error)
                    self.state = State.Error
                    self.sink.put(.Next(Box(.FailToLoadNext)))
                },
                completed: {
            })
    }

    public func fetchPlaylist(activity: Activity) -> SignalProducer<SoundCloudKit.Playlist, NSError> {
        switch activity.origin {
        case .Playlist(let playlist):
            return APIClient.sharedInstance.fetchPlaylist(playlist.id)
        case .Track:
            return SignalProducer.empty
        }
    }
}
