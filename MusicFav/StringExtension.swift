//
//  StringExtension.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/7/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation

extension String {
    static func tutorialString(key: String) -> String {
        return NSLocalizedString(key, tableName: "Tutorial",
                                          bundle: NSBundle.mainBundle(),
                                           value: key,
                                         comment: key)

    }
    func toDate() -> NSDate? {
        let dateFormatter = NSDateFormatter()
        let formats = ["yyyy/MM/dd HH:mm:ssZ",
                       "yyyy-MM-dd'T'HH:mm:ss.sssZ"]
        for f in formats {
            dateFormatter.dateFormat = f
            if let date = dateFormatter.dateFromString(self) {
                return date
            }
        }
        return nil
    }
}

extension NSDate {
    public var elapsedTime: String {
        let now           = NSDate()
        let passed        = now.timeIntervalSinceDate(self)
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
