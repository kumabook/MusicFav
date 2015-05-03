//
//  Logger.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 5/3/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation

class Logger {
    static func verbose(message: String) {
        GAI.sharedInstance().logger.verbose(message)
    }
    static func info(message: String) {
        GAI.sharedInstance().logger.info(message)
    }
    static func warning(message: String) {
        GAI.sharedInstance().logger.warning(message)
    }
    static func error(message: String) {
        GAI.sharedInstance().logger.error(message)
    }
    static func sendStartSession() {
        if let tracker = GAI.sharedInstance().defaultTracker {
            tracker.set(kGAISessionControl, value: "start")
            tracker.send(GAIDictionaryBuilder.createScreenView().build() as [NSObject:AnyObject])
        }
    }
    static func sendEndSession() {
        if let tracker = GAI.sharedInstance().defaultTracker {
            tracker.set(kGAISessionControl, value: "end")
            tracker.send(GAIDictionaryBuilder.createScreenView().build() as [NSObject:AnyObject])
        }
    }
    static func sendScreenView(viewController: UIViewController) {
        if let tracker = GAI.sharedInstance().defaultTracker {
            tracker.set(kGAIScreenName, value: reflect(viewController).summary)
            tracker.send(GAIDictionaryBuilder.createScreenView().build() as [NSObject:AnyObject])
        }
    }
    static func sendUIActionEvent(sender: UIViewController, action: String, label: String) {
        if let tracker = GAI.sharedInstance().defaultTracker {
            let _action = "\(reflect(sender).summary)#\(action)"
            let value   = FeedlyAPI.isLoggedIn ? 1 : 0
            let event = GAIDictionaryBuilder.createEventWithCategory("uiaction", action: _action, label: label, value: value)
            tracker.send(event.build() as [NSObject:AnyObject])
        }
    }
}