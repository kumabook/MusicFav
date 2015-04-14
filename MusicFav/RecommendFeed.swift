//
//  RecommendFeed.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/14/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import FeedlyKit

class RecommendFeed {
    class var ids: [String] {
        struct Static {
            static let ids: [String] = ["feed/http://spincoaster.com/feed",
                                        "feed/http://matome.naver.jp/feed/topic/1Hinb"]
        }
        return Static.ids
    }
}