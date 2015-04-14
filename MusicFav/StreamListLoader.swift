//
//  StreamListLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/15/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import FeedlyKit
import ReactiveCocoa
import LlamaKit
import FeedlyKit

class StreamListLoader {
    enum State {
        case Normal
        case Fetching
        case Updating
        case Error
    }

    enum Event {
        case StartLoading
        case CompleteLoading
        case FailToLoad(NSError)
        case StartUpdating
        case FailToUpdate(NSError)
        case CreateAt(Subscription)
        case RemoveAt(Int, Subscription, FeedlyKit.Category)
    }

    var apiClient:            FeedlyAPIClient  { get { return FeedlyAPIClient.sharedInstance }}
    var state:                State
    var signal:               HotSignal<Event>
    private var sink:         SinkOf<Event>
    var streamListOfCategory: [FeedlyKit.Category: [Stream]]

    init() {
        state                = .Normal
        streamListOfCategory = [:]
        let pipe = HotSignal<Event>.pipe()
        signal               = pipe.0
        sink                 = pipe.1
    }

    private func addSubscription(subscription: Subscription) {
        for category in subscription.categories {
            streamListOfCategory[category]!.append(subscription)
        }
    }

    private func removeSubscription(subscription: Subscription) {
        for category in subscription.categories {
            let index = find(self.streamListOfCategory[category]!, subscription)
            if let i = index {
                streamListOfCategory[category]!.removeAtIndex(i)
            }
        }
    }

    func refresh() {
        state = .Fetching
        sink.put(.StartLoading)
        fetch().deliverOn(MainScheduler()).start(
            next: { dic in
                self.sink.put(.StartLoading)
            }, error: { error in
                self.state = .Error
                self.sink.put(.FailToLoad(error))
            }, completed: {
                self.state = .Normal
                self.sink.put(.CompleteLoading)
        })
    }

    func fetch() -> ColdSignal<[FeedlyKit.Category: [Stream]]> {
        if apiClient.isLoggedIn {
            return self.fetchSubscriptions()
        } else {
            return self.fetchTrialFeeds()
        }
    }

    func fetchSubscriptions() -> ColdSignal<[FeedlyKit.Category: [Stream]]> {
        return apiClient.fetchCategories().merge({categoryListSignal in
            self.apiClient.fetchSubscriptions().map({ subscriptions in
                return categoryListSignal.map({ categories in
                    for category in categories {
                        self.streamListOfCategory[category] = [] as [Stream]
                    }
                    for subscription in subscriptions {
                        self.addSubscription(subscription)
                    }
                    return self.streamListOfCategory
                })
            })
        })
    }

    func fetchTrialFeeds() -> ColdSignal<[FeedlyKit.Category: [Stream]]> {
        return apiClient.fetchFeedsByIds(SampleFeed.samples().map({ $0.id })).map({feeds in
            let samplesCategory = FeedlyKit.Category(id: "feed/musicfav-samples",
                label: "Sample Feeds".localize())
            self.streamListOfCategory = [samplesCategory:feeds] as [FeedlyKit.Category: [Stream]]
            return self.streamListOfCategory
        })
    }

    func createCategory(label: String) -> FeedlyKit.Category? {
        if let profile = FeedlyAPIClient.sharedInstance.profile {
            let category = FeedlyKit.Category(label: label, profile: profile)
            streamListOfCategory[category] = []
            return category
        }
        return nil
    }

    func subscribeTo(subscribable: Subscribable, category: FeedlyKit.Category) {
        var subscription: Subscription?
        switch subscribable as Subscribable {
        case Subscribable.ToFeed(let feed):
            subscription = Subscription(feed: feed, categories: [category])
        case .ToBlog(let blog):
            subscription = Subscription(id: blog.feedId,
                title: blog.siteName,
                categories: [category])
        }
        if let s = subscription { subscribeTo(s) }
    }

    func subscribeTo(subscription: Subscription) {
        state = .Updating
        sink.put(.StartUpdating)
        FeedlyAPIClient.sharedInstance.client.subscribeTo(subscription) { (req, res, error) -> Void in
            if let e = error {
                self.state = .Error
                self.sink.put(.FailToUpdate(e))
            } else {
                self.addSubscription(subscription)
                self.state = .Normal
                self.sink.put(.CreateAt(subscription))
            }
        }
    }

    func unsubscribeTo(subscription: Subscription, index: Int, category: FeedlyKit.Category) {
        state = .Updating
        self.sink.put(.StartUpdating)
        apiClient.client.unsubscribeTo(subscription.id, completionHandler: { (req, res, error) -> Void in
            if let e = error {
                self.state = .Error
                self.sink.put(.FailToUpdate(e))
            } else {
                self.state = .Normal
                self.sink.put(.RemoveAt(index, subscription, category))
            }
        })
    }
}
