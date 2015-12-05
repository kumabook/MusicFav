//
//  ChannelLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 7/11/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import ReactiveCocoa
import Result
import FeedlyKit

class ChannelLoader {
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

    var categories: [GuideCategory]
    private var channelsOfCategory: [GuideCategory:[Channel]]
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
        self.state                    = .Init
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
        state           = .Normal
        searchDisposable?.dispose()
    }

    func channelsOf(category: GuideCategory) -> [Channel]? {
        return channelsOfCategory[category]
    }

    private func fetchNextGuideCategory() -> SignalProducer<Void, NSError> {
        state = State.Fetching
        observer.sendNext(.StartLoading)
        return YouTubeAPIClient.sharedInstance.fetchGuideCategories(categoriesPageToken).map {
            self.categories.appendContentsOf($0.items)
            self.categoriesPageToken = $0.nextPageToken
            for c in $0.items {
                self.channelsOfCategory[c]          = []
                self.channelsPageTokenOfCategory[c] = ""
            }
            self.observer.sendNext(.CompleteLoading)
            self.state = State.Normal
            if self.categoriesPageToken == nil {
                self.state = .Normal
            }
        }
    }

    private func fetchNextChannels(category: GuideCategory) -> SignalProducer<Void, NSError> {
        state = State.Fetching
        observer.sendNext(.StartLoading)
        return YouTubeAPIClient.sharedInstance.fetchChannels(category, pageToken: channelsPageTokenOfCategory[category]).map {
                self.channelsOfCategory[category]?.appendContentsOf($0.items)
                self.channelsPageTokenOfCategory[category] = $0.nextPageToken
                self.observer.sendNext(.CompleteLoading)
                self.state = State.Normal
            }
    }

    private func fetchNextSubscriptions() -> SignalProducer<Void, NSError> {
        state = State.Fetching
        observer.sendNext(.StartLoading)
        return YouTubeAPIClient.sharedInstance.fetchSubscriptions(subscriptionPageToken)
            .map {
                self.subscriptions.appendContentsOf($0.items)
                self.subscriptionPageToken = $0.nextPageToken
                self.observer.sendNext(.CompleteLoading)
                self.state = State.Normal
            }.mapError { e in
                self.observer.sendNext(.FailToLoad)
                self.state = State.Error
                return e
        }
    }

    private func searchNextChannels(query: String) -> SignalProducer<Void, NSError> {
        state = State.Fetching
        observer.sendNext(.StartLoading)
        return YouTubeAPIClient.sharedInstance.searchChannel(query, pageToken: searchPageToken)
            .map {
                self.searchResults.appendContentsOf($0.items)
                self.searchPageToken = $0.nextPageToken
                self.observer.sendNext(.CompleteLoading)
                self.state = State.Normal
            }.mapError { e in
                self.observer.sendNext(.FailToLoad)
                self.state = State.Error
                return e
        }
    }

    func needFetchCategories() -> Bool {
        return categoriesPageToken != nil
    }

    func fetchCategories() {
        if !needFetchCategories() { return }
        switch state {
        case .Init:     categoriesDisposable = fetchNextGuideCategory().start()
        case .Fetching: break
        case .Normal:   categoriesDisposable = fetchNextGuideCategory().start()
        case .Error:    categoriesDisposable = fetchNextGuideCategory().start()
        }
    }

    func needFetchChannels(category: GuideCategory) -> Bool {
        return channelsPageTokenOfCategory[category] != nil
    }

    func fetchChannels(category: GuideCategory) {
        if !needFetchChannels(category) { return }
        switch state {
        case .Init:     channelDisposableOfCategory[category] = fetchNextChannels(category).start()
        case .Fetching: break
        case .Normal:   channelDisposableOfCategory[category] = fetchNextChannels(category).start()
        case .Error:    channelDisposableOfCategory[category] = fetchNextChannels(category).start()
        }
    }

    func needFetchSubscriptions() -> Bool {
        return subscriptionPageToken != nil
    }

    func fetchSubscriptions() {
        if !needFetchSubscriptions() { return }
        switch state {
        case .Init:     subscriptionDisposable = fetchNextSubscriptions().start()
        case .Fetching: break
        case .Normal:   subscriptionDisposable = fetchNextSubscriptions().start()
        case .Error:    subscriptionDisposable = fetchNextSubscriptions().start()
        }
    }

    func needFetchSearchResults() -> Bool {
        return searchPageToken != nil
    }

    func searchChannels(query: String) {
        if query.isEmpty || !needFetchSearchResults() { return }
        switch state {
        case .Init:     searchDisposable = searchNextChannels(query).start()
        case .Fetching: break
        case .Normal:   searchDisposable = searchNextChannels(query).start()
        case .Error:    searchDisposable = searchNextChannels(query).start()
        }
    }
}