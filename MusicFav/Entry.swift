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
    var passedTime: String {
        let now           = NSDate()
        let publishedDate = NSDate(timeIntervalSince1970: NSTimeInterval(Double(published)/1000))
        let passed        = now.timeIntervalSinceDate(publishedDate)
        let minute: Int  = Int(passed) / 60
        if minute <= 1 {
            return "1 minute ago"
        }
        if minute < 60 {
            return "\(minute)" + " minutes ago"
        }
        let hour = minute / 60;
        if hour <= 1 {
            return "\(hour)" + " hour ago"
        }
        if (hour < 24) {
            return "\(hour)" + " hours ago"
        }
        let day = hour / 24;
        if day <= 1 {
            return "\(day)" + " day ago"
        }
        return "\(day)" + " days ago"
    }
}
