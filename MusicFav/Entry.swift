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
    var thumbnailURL: NSURL? {
        if let v = visual, url = v.url.toURL() {
            if url.scheme != nil { return url }
        }
        if let links = enclosure {
            for link in links {
                if let url = link.href.toURL() {
                    if url.scheme != nil { return url }
                }
            }
        }
        if let url = extractImgSrc() {
            return url
        }
        return nil
    }
    func extractImgSrc() -> NSURL? {
        if let html = content?.content {
            var regex = NSRegularExpression(pattern: "<img.*src\\s*=\\s*[\"\'](.*?)[\"\'].*>",
                                            options: NSRegularExpressionOptions.allZeros,
                                              error: nil)
            if let r = regex {
                let length = html.lengthOfBytesUsingEncoding(NSString.defaultCStringEncoding())
                if let result  = r.firstMatchInString(html, options: NSMatchingOptions.allZeros, range: NSMakeRange(0, count(html))) {
                    let str = html as NSString
                    for i in 0...result.numberOfRanges - 1 {
                        let range = result.rangeAtIndex(i)
                        let str = html as NSString
                        if let url = str.substringWithRange(range).toURL() {
                            return url
                        }
                    }
                }
            }
        }
        return nil
   }
}
