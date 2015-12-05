//
//  SoundCloudUserLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/24/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import SoundCloudKit
import ReactiveCocoa
import MusicFeeder
import Breit
import FeedlyKit

extension SoundCloudKit.User {
    var thumbnailURL: NSURL? { return avatarUrl.toURL() }

    func toSubscription() -> Subscription {
        return Subscription(id: "feed/http://feeds.soundcloud.com/users/soundcloud:users:\(id)/sounds.rss",
                         title: username,
                    categories: [])
    }
}

class SoundCloudUserLoader {
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

    var followings:     [SoundCloudKit.User]
    var searchResults:  [SoundCloudKit.User]

    var state:          State
    var signal:         Signal<Event, NSError>
    var observer:       Signal<Event, NSError>.Observer

    var followingsDisposable: Disposable?
    var hasNextFollowings:    Bool

    var searchDisposable:     Disposable?
    var hasNextSearch:        Bool

    var user: SoundCloudKit.User? {
        return APIClient.me
    }

    init() {
        followings                 = []
        searchResults              = []
        self.state                 = .Init
        let pipe                   = Signal<Event, NSError>.pipe()
        signal                     = pipe.0
        observer                   = pipe.1
        followingsDisposable       = nil
        hasNextFollowings          = true
        searchDisposable           = nil
        hasNextSearch              = true
    }

    func clearSearch() {
        searchResults = []
    }

    private func fetchNextFollowings() -> SignalProducer<Void, NSError> {
        if user == nil { return SignalProducer.empty }
        state = State.Fetching
        observer.sendNext(.StartLoading)
        return APIClient.sharedInstance.fetchFollowingsOf(user!).map {
            self.hasNextFollowings = false
            self.followings.appendContentsOf($0)
            self.observer.sendNext(.CompleteLoading)
            self.state = State.Normal
            }.mapError {
                self.hasNextFollowings = true
                self.observer.sendFailed($0)
                self.state = State.Error
                return $0
        }
    }

    func needFetchFollowings() -> Bool {
        return hasNextFollowings
    }

    func fetchFollowings() {
        if !needFetchFollowings() { return }
        switch state {
        case .Init:     followingsDisposable = fetchNextFollowings().start()
        case .Fetching: break
        case .Normal:   followingsDisposable = fetchNextFollowings().start()
        case .Error:    followingsDisposable = fetchNextFollowings().start()
        }
    }

    func searchUsers(query: String) {
        if state == State.Fetching { return }
        state = State.Fetching
        observer.sendNext(.StartLoading)
        APIClient.sharedInstance.fetchUsers(query).on(
            failed: { e in
                self.hasNextSearch = true
                self.observer.sendFailed(e)
                self.state = State.Error
            }, next: { users in
                self.hasNextSearch = false
                self.searchResults.appendContentsOf(users)
                self.observer.sendNext(.CompleteLoading)
                self.state = State.Normal
        }).start()
    }
}