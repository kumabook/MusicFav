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
        if let profile = FeedlyAPIClient.sharedInstance.profile {
            return FeedlyKit.Category.All(profile.id)
        } else {
            return StreamListLoader.sampleSubscriptions()[0]
        }
    }

    init() {
        state                = .Normal
        streamListOfCategory = [:]
        let pipe = HotSignal<Event>.pipe()
        signal               = pipe.0
        sink                 = pipe.1
        uncategorized        = FeedlyKit.Category.Uncategorized()
        if let userId = apiClient.profile?.id {
            uncategorized = FeedlyKit.Category.Uncategorized(userId)
        }
        streamListOfCategory[uncategorized] = []
        if !apiClient.isLoggedIn {
            streamListOfCategory[uncategorized]?.extend(StreamListLoader.sampleSubscriptions() as [Stream])
        }
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
            return ColdSignal<[FeedlyKit.Category: [Stream]]>.empty()
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

    func createCategory(label: String) -> FeedlyKit.Category? {
        if let profile = FeedlyAPIClient.sharedInstance.profile {
            let category = FeedlyKit.Category(label: label, profile: profile)
            streamListOfCategory[category] = []
            return category
        }
        return nil
    }

    func subscribeTo(subscribable: Subscribable, categories: [FeedlyKit.Category]) {
        var subscription: Subscription?
        switch subscribable as Subscribable {
        case Subscribable.ToFeed(let feed):
            subscription = Subscription(feed: feed, categories: categories)
        case .ToBlog(let blog):
            subscription = Subscription(id: blog.feedId,
                title: blog.siteName,
                categories: categories)
        }
        if let s = subscription { subscribeTo(s) }
    }

    func subscribeTo(subscription: Subscription) {
        state = .Updating
        sink.put(.StartUpdating)
        if !apiClient.isLoggedIn {
            self.addSubscription(subscription)
            self.state = .Normal
            self.sink.put(.CreateAt(subscription))
            return
        }
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
        if !apiClient.isLoggedIn {
            self.removeSubscription(subscription)
            self.state = .Normal
            self.sink.put(.RemoveAt(index, subscription, category))
            return
        }
        apiClient.client.unsubscribeTo(subscription.id, completionHandler: { (req, res, error) -> Void in
            if let e = error {
                self.state = .Error
                self.sink.put(.FailToUpdate(e))
            } else {
                self.removeSubscription(subscription)
                self.state = .Normal
                self.sink.put(.RemoveAt(index, subscription, category))
            }
        })
    }
}
