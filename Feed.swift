//
//  Feed.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/2/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import FeedlyKit
import MusicFeeder

public class SubscribableFeed: Subscribable {
    let feed: Feed
    init(feed: Feed) {
        self.feed = feed
    }
    public func toSubscription() -> Subscription {
        return Subscription(feed: feed, categories: [])
    }
}