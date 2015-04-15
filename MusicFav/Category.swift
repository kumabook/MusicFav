//
//  Category.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/15/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import FeedlyKit

extension FeedlyKit.Category {
    class func Uncategorized() -> FeedlyKit.Category {
        return FeedlyKit.Category(id: "uncategorized", label: "Uncategorized")
    }
}
