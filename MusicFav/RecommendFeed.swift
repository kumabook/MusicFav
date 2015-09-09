//
//  RecommendFeed.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/14/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import FeedlyKit

public class RecommendFeed {
    public class var ids: [String] {
        struct Static {
            static let ids: [String] = ["feed/http://spincoaster.com/feed",
                                        "feed/http://matome.naver.jp/feed/topic/1Hinb",
                                        "feed/http://basement-times.com/feed/",
                                        "feed/http://uncannyzine.com/feed",
                                        "feed/http://nichemusic.info/feed/",
                                        "feed/http://makebelievemelodies.com/?feed=rss2",
                                        "feed/http://andithereport.com/feed/"]
        }
        return Static.ids
    }

    public class func defaultStream() -> Stream {
        if let profile = CloudAPIClient.profile {
            return FeedlyKit.Category.All(profile.id)
        } else {
            return Subscription(id: "feed/http://spincoaster.com/feed",
                             title: "Spincoaster (sample)",
                         visualUrl: nil,
                        categories: [])
        }
    }
}