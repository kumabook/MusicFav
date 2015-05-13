//
//  NSDateExtension.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 5/11/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation

extension NSDate {
    var timestamp: Int64 {
        return Int64(timeIntervalSince1970 * 1000)
    }
    var yesterDay: NSDate {
        return NSDate(timeInterval: NSTimeInterval(-1 * 24 * 60 * 60), sinceDate: self)
    }
}
