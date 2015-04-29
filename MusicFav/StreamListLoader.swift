//
//  StreamListLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/15/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import FeedlyKit
import ReactiveCocoa
import LlamaKit

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
        case RemoveAt(Int, Subscription, FeedlyKit.Category)
    }

    var apiClient:            CloudAPIClient { return CloudAPIClient.sharedInstance }
    var state:                State
    var signal:               Signal<Event, NSError>
    private var sink:         SinkOf<ReactiveCocoa.Event<Event, NSError>>
    var disposable:           Disposable?
    var streamListOfCategory: [FeedlyKit.Category: [Stream]]
    var uncategorized:        FeedlyKit.Category
    var categories: [FeedlyKit.Category] {
        return streamListOfCategory.keys.array.sorted({ (first, second) -> Bool in
            return first == self.uncategorized || first.label > second.label
        })
    }
    var uncategorizedStreams: [Stream] {
        return streamListOfCategory[uncategorized]!
    }

    class func sampleSubscriptions() -> [Subscription] {
        return [Subscription(id: "feed/http://spincoaster.com/feed",
                          title: "Spincoaster (sample)",
                     categories: []),
                Subscription(id: "feed/http://matome.naver.jp/feed/topic/1Hinb",
                          title: "Naver matome (sample)",
                     categories: [])]
    }

    class func defaultStream() -> Stream {
        if let profile = FeedlyAPI.profile {
            return FeedlyKit.Category.All(profile.id)
        } else {
            return StreamListLoader.sampleSubscriptions()[0]
        }
    }

    init() {
        state                = .Normal
        streamListOfCategory = [:]
        let pipe = Signal<Event, NSError>.pipe()
        signal               = pipe.0
        sink                 = pipe.1
        uncategorized        = FeedlyKit.Category.Uncategorized()
        if let userId = FeedlyAPI.profile?.id {
            uncategorized = FeedlyKit.Category.Uncategorized(userId)
        }
        streamListOfCategory[uncategorized] = []
    }

    deinit {
        dispose()
    }

    func dispose() {
        disposable?.dispose()
        disposable = nil
    }

    private func addSubscription(subscription: Subscription) {
        var categories = subscription.categories.count > 0 ? subscription.categories : [uncategorized]
        for category in categories {
            if find(streamListOfCategory[category]!, subscription) == nil {
                streamListOfCategory[category]!.append(subscription)
            }
        }
    }

    private func removeSubscription(subscription: Subscription) {
        var categories = subscription.categories.count > 0 ? subscription.categories : [uncategorized]
        for category in categories {
            let index = find(self.streamListOfCategory[category]!, subscription)
            if let i = index {
                streamListOfCategory[category]!.removeAtIndex(i)
            }
        }
    }

    func refresh() {
        if !apiClient.isLoggedIn {
            sink.put(.Next(Box(.StartLoading)))
            if streamListOfCategory[uncategorized]!.count == 0 {
                streamListOfCategory[uncategorized]?.extend(StreamListLoader.sampleSubscriptions() as [Stream])
            }
            self.sink.put(.Next(Box(.CompleteLoading)))
            return
        }
        streamListOfCategory                = [:]
        streamListOfCategory[uncategorized] = []
        state = .Fetching
        sink.put(.Next(Box(.StartLoading)))
        disposable?.dispose()
        disposable = self.fetchSubscriptions() |> startOn(UIScheduler()) |> start(
            next: { dic in
                self.sink.put(.Next(Box(.StartLoading)))
            }, error: { error in
                self.state = .Error
                self.sink.put(.Next(Box(.FailToLoad(error))))
            }, completed: {
                self.state = .Normal
                self.sink.put(.Next(Box(.CompleteLoading)))
        })
    }

    func fetchSubscriptions() -> SignalProducer<[FeedlyKit.Category: [Stream]], NSError> {
        return apiClient.fetchCategories() |> map { categories in
            for category in categories {
                self.streamListOfCategory[category] = [] as [Stream]
            }
            return self.apiClient.fetchSubscriptions() |> map { subscriptions in
                for subscription in subscriptions {
                    self.addSubscription(subscription)
                }
                return self.streamListOfCategory
            }
        } |> flatten(.Merge)
    }

    func createCategory(label: String) -> FeedlyKit.Category? {
        if let profile = FeedlyAPI.profile {
            let category = FeedlyKit.Category(label: label, profile: profile)
            streamListOfCategory[category] = []
            return category
        }
        return nil
    }

    func subscribeTo(subscribable: Subscribable, categories: [FeedlyKit.Category]) -> SignalProducer<Subscription, NSError> {
        var subscription: Subscription?
        switch subscribable as Subscribable {
        case Subscribable.ToFeed(let feed):
            subscription = Subscription(feed: feed, categories: categories)
        case .ToBlog(let blog):
            subscription = Subscription(id: blog.feedId,
                title: blog.siteName,
                categories: categories)
        }
        if let s = subscription {
            return subscribeTo(s)
        } else {
            return SignalProducer<Subscription, NSError>.empty
        }
    }

    func subscribeTo(subscription: Subscription) -> SignalProducer<Subscription, NSError> {
        return SignalProducer<Subscription, NSError> { (sink, disposable) in
            if !self.apiClient.isLoggedIn {
                self.addSubscription(subscription)
                self.state = .Normal
                sink.put(.Next(Box(subscription)))
                sink.put(.Completed)
            } else {
                CloudAPIClient.sharedInstance.subscribeTo(subscription) { (req, res, error) -> Void in
                    if let e = error {
                        self.state = .Error
                        self.sink.put(.Next(Box(.FailToUpdate(e))))
                        sink.put(.Error(Box(e)))
                    } else {
                        self.addSubscription(subscription)
                        self.state = .Normal
                        sink.put(.Next(Box(subscription)))
                        sink.put(.Completed)
                    }
                }
            }
        }
    }

    func unsubscribeTo(subscription: Subscription, index: Int, category: FeedlyKit.Category) {
        state = .Updating
        self.sink.put(.Next(Box(.StartUpdating)))
        if !apiClient.isLoggedIn {
            self.removeSubscription(subscription)
            self.state = .Normal
            self.sink.put(.Next(Box(.RemoveAt(index, subscription, category))))
            return
        }
        apiClient.unsubscribeTo(subscription.id, completionHandler: { (req, res, error) -> Void in
            if let e = error {
                self.state = .Error
                self.sink.put(.Next(Box(.FailToUpdate(e))))
            } else {
                self.removeSubscription(subscription)
                self.state = .Normal
                self.sink.put(.Next(Box(.RemoveAt(index, subscription, category))))
            }
        })
    }
}
