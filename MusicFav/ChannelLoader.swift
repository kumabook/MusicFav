//
//  ChannelLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 7/11/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import ReactiveCocoa
import Result
import Box
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
    var sink:           SinkOf<ReactiveCocoa.Event<Event, NSError>>

    var subscriptions: [YouTubeSubscription]
    var channels:      [Channel]
    var categoriesPageToken: String?
    var channelsPageTokenOfCategory: [GuideCategory: String]
    var subscriptionPageToken: String?
    var channelPageToken: String?

    init() {
        categories                    = []
        channelsOfCategory            = [:]
        subscriptions                 = []
        channels                      = []
        self.state                    = .Init
        let pipe                      = Signal<Event, NSError>.pipe()
        signal                        = pipe.0
        sink                          = pipe.1
        categoriesPageToken           = ""
        subscriptionPageToken         = ""
        channelsPageTokenOfCategory   = [:]
    }

    func channelsOf(category: GuideCategory) -> [Channel]? {
        return channelsOfCategory[category]
    }

    private func fetchNextGuideCategory() -> SignalProducer<Void, NSError> {
        state = State.Fetching
        sink.put(ReactiveCocoa.Event<Event, NSError>.Next(Box(.StartLoading)))
        return YouTubeAPIClient.sharedInstance.fetchGuideCategories(categoriesPageToken) |> map {
            self.categories.extend($0.items)
            self.categoriesPageToken = $0.nextPageToken
            for c in $0.items {
                self.channelsOfCategory[c]          = []
                self.channelsPageTokenOfCategory[c] = ""
            }
            self.sink.put(ReactiveCocoa.Event<Event, NSError>.Next(Box(.CompleteLoading)))
            self.state = State.Normal
            if self.categoriesPageToken == nil {
                self.state = .Normal
            }
        }
    }

    private func fetchNextChannels(category: GuideCategory) -> SignalProducer<Void, NSError> {
        state = State.Fetching
        sink.put(ReactiveCocoa.Event<Event, NSError>.Next(Box(.StartLoading)))
        return YouTubeAPIClient.sharedInstance.fetchChannels(category, pageToken: channelsPageTokenOfCategory[category]) |> map {
                self.channelsOfCategory[category]?.extend($0.items)
                self.channelsPageTokenOfCategory[category] = $0.nextPageToken
                self.sink.put(ReactiveCocoa.Event<Event, NSError>.Next(Box(.CompleteLoading)))
                self.state = State.Normal
            }
    }

    private func fetchNextSubscriptions() -> SignalProducer<Void, NSError> {
        state = State.Fetching
        sink.put(ReactiveCocoa.Event<Event, NSError>.Next(Box(.StartLoading)))
        return YouTubeAPIClient.sharedInstance.fetchSubscriptions(subscriptionPageToken)
            |> map {
                self.subscriptions.extend($0.items)
                self.subscriptionPageToken = $0.nextPageToken
                self.sink.put(ReactiveCocoa.Event<Event, NSError>.Next(Box(.CompleteLoading)))
                self.state = State.Normal
            } |> mapError { e in
                self.sink.put(ReactiveCocoa.Event<Event, NSError>.Next(Box(.FailToLoad)))
                self.state = State.Error
                return e
        }
    }

    private func fetchChannelsByMusic() -> SignalProducer<Void, NSError> {
        state = State.Fetching
        sink.put(ReactiveCocoa.Event<Event, NSError>.Next(Box(.StartLoading)))
        return YouTubeAPIClient.sharedInstance.searchChannel("music", pageToken: nil)
            |> map {
                self.channels.extend($0.items)
                self.channelPageToken = $0.nextPageToken
                self.sink.put(ReactiveCocoa.Event<Event, NSError>.Next(Box(.CompleteLoading)))
                self.state = State.Normal
            } |> mapError { e in
                self.sink.put(ReactiveCocoa.Event<Event, NSError>.Next(Box(.FailToLoad)))
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
        case .Init:     fetchNextGuideCategory().start()
        case .Fetching: break
        case .Normal:   fetchNextGuideCategory().start()
        case .Error:    fetchNextGuideCategory().start()
        }
    }

    func needFetchChannels(category: GuideCategory) -> Bool {
        return channelsPageTokenOfCategory[category] != nil
    }

    func fetchChannels(category: GuideCategory) {
        if !needFetchChannels(category) { return }
        switch state {
        case .Init:     fetchNextChannels(category).start()
        case .Fetching: break
        case .Normal:   fetchNextChannels(category).start()
        case .Error:    fetchNextChannels(category).start()
        }
    }

    func needFetchSubscriptions() -> Bool {
        return subscriptionPageToken != nil
    }

    func fetchSubscriptions() {
        if !needFetchSubscriptions() { return }
        switch state {
        case .Init:     fetchNextSubscriptions().start()
        case .Fetching: break
        case .Normal:   fetchNextSubscriptions().start()
        case .Error:    fetchNextSubscriptions().start()
        }
    }

    func searchChannelsByMusic() {
        if channels.count > 0 { return }
        switch state {
        case .Init:     fetchChannelsByMusic().start()
        case .Fetching: break
        case .Normal:   fetchChannelsByMusic().start()
        case .Error:    fetchChannelsByMusic().start()
        }
    }
}