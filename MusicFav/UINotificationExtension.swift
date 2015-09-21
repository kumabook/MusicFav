//
//  UINotificationExtension.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 5/13/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import UIKit
import FeedlyKit
import MusicFeeder

enum NotificationType: String {
    case NewTracks      = "new_tracks"
    case RecommendLogin = "recommend_login"
    init?(userInfo: [NSObject: AnyObject]) {
        if let t = userInfo["type"] as? String, type = NotificationType(rawValue: t) {
            self = type
        } else {
            return nil
        }
    }
}

extension UILocalNotification {
    static var notificationTimeMinutesInterval:   Int            { return 30 }
    static var updateCheckInterval:               NSTimeInterval { return NSTimeInterval(60 * notificationTimeMinutesInterval * 2) }
    static var defaultNotificationDateComponents: NSDateComponents {
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components([NSCalendarUnit.Year, NSCalendarUnit.Month, NSCalendarUnit.Day, NSCalendarUnit.Hour, NSCalendarUnit.Minute], fromDate: NSDate())
        components.hour   = 8
        components.minute = 0
        components.second = 0
        return components
    }
    static func setup(application: UIApplication) {
        application.setMinimumBackgroundFetchInterval(UILocalNotification.updateCheckInterval)
        application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: .Badge, categories: nil))
        application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: .Alert, categories: nil))
        application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: .Sound, categories: nil))
    }
    static func buildNewTracksInfo(application: UIApplication, tracks: [Track]) -> [String] {
        if let notifications = application.scheduledLocalNotifications {
            var tracksInfo: Set<String> = Set(tracks.map { "\($0.provider)/\($0.identifier)" })
            for n in notifications {
                if let userInfo = n.userInfo, type = NotificationType(userInfo: userInfo) {
                    switch type {
                    case .NewTracks:
                        if let ts = userInfo["tracks"] as? [String] {
                            tracksInfo = tracksInfo.union(ts)
                        }
                    case .RecommendLogin:
                        break
                    }
                }
            }
            return Array(tracksInfo)
        }
        return []
    }
    static func newTracksNotification(tracksInfo: [String], fireDate: NSDate) -> UILocalNotification {
        let notification = UILocalNotification()
        notification.alertAction = "OK"
        notification.alertBody   = String(format:"New %d tracks are added.".localize(), tracksInfo.count)
        notification.applicationIconBadgeNumber = 1
        notification.fireDate    = fireDate
        notification.timeZone    = NSTimeZone.defaultTimeZone()
        notification.userInfo = ["type": NotificationType.NewTracks.rawValue, "tracks": tracksInfo]
        return notification
    }
}