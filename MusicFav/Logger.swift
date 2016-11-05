//
//  Logger.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 5/3/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import FeedlyKit
import MusicFeeder

class Logger {
    static func verbose(_ message: String) {
        GAI.sharedInstance().logger.verbose(message)
    }
    static func info(_ message: String) {
        GAI.sharedInstance().logger.info(message)
    }
    static func warning(_ message: String) {
        GAI.sharedInstance().logger.warning(message)
    }
    static func error(_ message: String) {
        GAI.sharedInstance().logger.error(message)
    }
    static func sendStartSession() {
        if let tracker = GAI.sharedInstance().defaultTracker {
            tracker.set(kGAISessionControl, value: "start")
            tracker.send(GAIDictionaryBuilder.createScreenView().build() as NSDictionary? as? [AnyHashable: Any] ?? [:])
        }
    }
    static func sendEndSession() {
        if let tracker = GAI.sharedInstance().defaultTracker {
            tracker.set(kGAISessionControl, value: "end")
            tracker.send(GAIDictionaryBuilder.createScreenView().build() as NSDictionary? as? [AnyHashable: Any] ?? [:])
        }
    }
    static func sendScreenView(_ viewController: UIViewController) {
        if let tracker = GAI.sharedInstance().defaultTracker {
            tracker.set(kGAIScreenName, value: Mirror(reflecting: viewController).description)
            tracker.send(GAIDictionaryBuilder.createScreenView().build() as NSDictionary? as? [AnyHashable: Any] ?? [:])
        }
    }
    static func sendUIActionEvent(_ sender: UIViewController, action: String, label: String) {
        if let tracker = GAI.sharedInstance().defaultTracker {
            let _action = "\(Mirror(reflecting: sender).description)#\(action)"
            let value   = CloudAPIClient.isLoggedIn ? 1 : 0
            let event = GAIDictionaryBuilder.createEvent(withCategory: "uiaction", action: _action, label: label, value: value as NSNumber!)
            tracker.send(event?.build() as NSDictionary? as? [AnyHashable: Any] ?? [:])
        }
    }
}
