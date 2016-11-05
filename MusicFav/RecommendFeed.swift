//
//  RecommendFeed.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/14/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import FeedlyKit

open class RecommendFeed {
    open class var ids: [String] {
        struct Static {
            static let ids: [String] = ["feed/http://matome.naver.jp/feed/topic/1Hinb",
                                        "feed/http://spincoaster.com/feed",
                                        "feed/http://basement-times.com/feed/",
                                        "feed/http://uncannyzine.com/feed",
                                        "feed/http://bilingualnews.libsyn.com//rss",
                                        "feed/http://nichemusic.info/feed/",
                                        "feed/http://makebelievemelodies.com/?feed=rss2",
                                        "feed/http://andithereport.com/feed/",
                                        "feed/https://www.youtube.com/feeds/videos.xml?channel_id=UCFleWgo1LPbSzsf_V7i8Nhw"]
        }
        return Static.ids
    }

    open class func sampleStream() -> FeedlyKit.Stream {
        return Subscription(id: "feed/http://spincoaster.com/feed",
                         title: "Spincoaster (sample)",
                     visualUrl: nil,
                    categories: [])
    }
}
