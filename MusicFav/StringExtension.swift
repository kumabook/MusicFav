//
//  StringExtension.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/7/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation

extension String {
    static func tutorialString(_ key: String) -> String {
        return NSLocalizedString(key, tableName: "Tutorial",
                                          bundle: Bundle.main,
                                           value: key,
                                         comment: key)

    }
    func toDate() -> Date? {
        let dateFormatter = DateFormatter()
        let formats = ["yyyy/MM/dd HH:mm:ssZ",
                       "yyyy-MM-dd'T'HH:mm:ss.sssZ"]
        for f in formats {
            dateFormatter.dateFormat = f
            if let date = dateFormatter.date(from: self) {
                return date
            }
        }
        return nil
    }
}

extension Date {
    public var elapsedTime: String {
        let now           = Date()
        let passed        = now.timeIntervalSince(self)
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
