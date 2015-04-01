//
//  Entry.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/1/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import FeedlyKit

extension Entry {
    var url: NSURL? {
        if let alternate = self.alternate {
            if alternate.count > 0 {
                let vc = EntryWebViewController()
                return NSURL(string: alternate[0].href)!
            }
        }
        return nil
    }
}
