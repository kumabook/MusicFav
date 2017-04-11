//
//  SoundCloudUserLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/24/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import SoundCloudKit
import ReactiveSwift
import MusicFeeder
import Breit
import FeedlyKit

extension SoundCloudKit.User {
    var thumbnailURL: URL? { return avatarUrl.toURL() }

    func toSubscription() -> Subscription {
        return Subscription(id: "feed/http://feeds.soundcloud.com/users/soundcloud:users:\(id)/sounds.rss",
                         title: username,
                    categories: [])
    }
}

class SoundCloudUserLoader {
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
        self.state                 = .init
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

    fileprivate func fetchNextFollowings() -> SignalProducer<Void, NSError> {
        if user == nil { return SignalProducer.empty }
        state = State.fetching
        observer.send(value: .startLoading)
        return APIClient.sharedInstance.fetchFollowingsOf(user!).map {
            self.hasNextFollowings = false
            self.followings.append(contentsOf: $0)
            self.observer.send(value: .completeLoading)
            self.state = State.normal
            }.mapError {
                self.hasNextFollowings = true
                self.observer.send(error: $0)
                self.state = State.error
                return $0
        }
    }

    func needFetchFollowings() -> Bool {
        return hasNextFollowings
    }

    func fetchFollowings() {
        if !needFetchFollowings() { return }
        switch state {
        case .init:     followingsDisposable = fetchNextFollowings().start()
        case .fetching: break
        case .normal:   followingsDisposable = fetchNextFollowings().start()
        case .error:    followingsDisposable = fetchNextFollowings().start()
        }
    }

    func searchUsers(_ query: String) {
        if state == State.fetching { return }
        state = State.fetching
        observer.send(value: .startLoading)
        APIClient.sharedInstance.fetchUsers(query).on(
            failed: { e in
                self.hasNextSearch = true
                self.observer.send(error: e)
                self.state = State.error
        }, value: { users in
            self.hasNextSearch = false
            self.searchResults.append(contentsOf: users)
            self.observer.send(value: .completeLoading)
            self.state = State.normal
        }).start()
    }
}
