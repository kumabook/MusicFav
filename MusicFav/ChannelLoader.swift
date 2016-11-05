//
//  ChannelLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 7/11/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import ReactiveSwift
import Result
import FeedlyKit

class ChannelLoader {
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

    var categories: [GuideCategory]
    fileprivate var channelsOfCategory: [GuideCategory:[Channel]]
    var offset  = 0
    var perPage = 5
    var state:          State
    var signal:         Signal<Event, NSError>
    var observer:       Signal<Event, NSError>.Observer

    var subscriptions:               [YouTubeSubscription]
    var channels:                    [Channel]
    var searchResults:               [Channel]
    var channelsPageTokenOfCategory: [GuideCategory: String]
    var categoriesPageToken:   String?
    var subscriptionPageToken: String?
    var channelPageToken:      String?
    var searchPageToken:       String?

    var channelDisposableOfCategory: [GuideCategory: Disposable?]
    var categoriesDisposable:        Disposable?
    var subscriptionDisposable:      Disposable?
    var searchDisposable:            Disposable?

    init() {
        categories                    = []
        channelsOfCategory            = [:]
        subscriptions                 = []
        channels                      = []
        searchResults                 = []
        self.state                    = .init
        let pipe                      = Signal<Event, NSError>.pipe()
        signal                        = pipe.0
        observer                      = pipe.1
        categoriesPageToken           = ""
        subscriptionPageToken         = ""
        searchPageToken               = ""
        channelsPageTokenOfCategory   = [:]
        channelDisposableOfCategory   = [:]
    }

    func clearSearch() {
        searchResults   = []
        searchPageToken = ""
        state           = .normal
        searchDisposable?.dispose()
    }

    func channelsOf(_ category: GuideCategory) -> [Channel]? {
        return channelsOfCategory[category]
    }

    fileprivate func fetchNextGuideCategory() -> SignalProducer<Void, NSError> {
        state = State.fetching
        observer.send(value: .startLoading)
        return YouTubeAPIClient.sharedInstance.fetchGuideCategories(categoriesPageToken).map {
            self.categories.append(contentsOf: $0.items)
            self.categoriesPageToken = $0.nextPageToken
            for c in $0.items {
                self.channelsOfCategory[c]          = []
                self.channelsPageTokenOfCategory[c] = ""
            }
        
            
            self.observer.send(value: .completeLoading)
            self.state = State.normal
            if self.categoriesPageToken == nil {
                self.state = .normal
            }
        }
    }

    fileprivate func fetchNextChannels(_ category: GuideCategory) -> SignalProducer<Void, NSError> {
        state = State.fetching
        observer.send(value: .startLoading)
        return YouTubeAPIClient.sharedInstance.fetchChannels(category, pageToken: channelsPageTokenOfCategory[category]).map {
                self.channelsOfCategory[category]?.append(contentsOf: $0.items)
                self.channelsPageTokenOfCategory[category] = $0.nextPageToken
                self.observer.send(value: .completeLoading)
                self.state = State.normal
            }
    }

    fileprivate func fetchNextSubscriptions() -> SignalProducer<Void, NSError> {
        state = State.fetching
        observer.send(value: .startLoading)
        return YouTubeAPIClient.sharedInstance.fetchSubscriptions(subscriptionPageToken)
            .map {
                self.subscriptions.append(contentsOf: $0.items)
                self.subscriptionPageToken = $0.nextPageToken
                self.observer.send(value: .completeLoading)
                self.state = State.normal
            }.mapError { e in
                self.observer.send(value: .failToLoad)
                self.state = State.error
                return e
        }
    }

    fileprivate func searchNextChannels(_ query: String) -> SignalProducer<Void, NSError> {
        state = State.fetching
        observer.send(value: .startLoading)
        return YouTubeAPIClient.sharedInstance.searchChannel(query, pageToken: searchPageToken)
            .map {
                self.searchResults.append(contentsOf: $0.items)
                self.searchPageToken = $0.nextPageToken
                self.observer.send(value: .completeLoading)
                self.state = State.normal
            }.mapError { e in
                self.observer.send(value: .failToLoad)
                self.state = State.error
                return e
        }
    }

    func needFetchCategories() -> Bool {
        return categoriesPageToken != nil
    }

    func fetchCategories() {
        if !needFetchCategories() { return }
        switch state {
        case .init:     categoriesDisposable = fetchNextGuideCategory().start()
        case .fetching: break
        case .normal:   categoriesDisposable = fetchNextGuideCategory().start()
        case .error:    categoriesDisposable = fetchNextGuideCategory().start()
        }
    }

    func needFetchChannels(_ category: GuideCategory) -> Bool {
        return channelsPageTokenOfCategory[category] != nil
    }

    func fetchChannels(_ category: GuideCategory) {
        if !needFetchChannels(category) { return }
        switch state {
        case .init:     channelDisposableOfCategory[category] = fetchNextChannels(category).start()
        case .fetching: break
        case .normal:   channelDisposableOfCategory[category] = fetchNextChannels(category).start()
        case .error:    channelDisposableOfCategory[category] = fetchNextChannels(category).start()
        }
    }

    func needFetchSubscriptions() -> Bool {
        return subscriptionPageToken != nil
    }

    func fetchSubscriptions() {
        if !needFetchSubscriptions() { return }
        switch state {
        case .init:     subscriptionDisposable = fetchNextSubscriptions().start()
        case .fetching: break
        case .normal:   subscriptionDisposable = fetchNextSubscriptions().start()
        case .error:    subscriptionDisposable = fetchNextSubscriptions().start()
        }
    }

    func needFetchSearchResults() -> Bool {
        return searchPageToken != nil
    }

    func searchChannels(_ query: String) {
        if query.isEmpty || !needFetchSearchResults() { return }
        switch state {
        case .init:     searchDisposable = searchNextChannels(query).start()
        case .fetching: break
        case .normal:   searchDisposable = searchNextChannels(query).start()
        case .error:    searchDisposable = searchNextChannels(query).start()
        }
    }
}
