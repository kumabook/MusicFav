//
//  GAIConfig.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 5/1/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import SwiftyJSON

open class GAIConfig {
    enum LogLevel: String {
        case None    = "none"
        case Error   = "error"
        case Warning = "warning"
        case Info    = "info"
        case Verbose = "verbose"
        var gaiLogLevel: GAILogLevel {
            switch self {
            case .None:    return GAILogLevel.none
            case .Error:   return GAILogLevel.error
            case .Warning: return GAILogLevel.warning
            case .Info:    return GAILogLevel.info
            case .Verbose: return GAILogLevel.verbose
            }
        }
    }
    open class func setup(_ filePath: String) {
        let gai                     = GAI.sharedInstance()
        let data                    = try? Data(contentsOf: URL(fileURLWithPath: filePath))
        let jsonObject: AnyObject?  = try! JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers) as AnyObject?
        let json                    = JSON(jsonObject!)
        
        if let trackerId = json["tracker_id"].string {
            if trackerId.range(of: "UA-") == nil {
                return
            } else {
                let _ = gai?.tracker(withTrackingId: trackerId)
            }
        }

        gai?.trackUncaughtExceptions = true;
        if let dispatchInterval = json["dispatch_inverval"].int {
            gai?.dispatchInterval = TimeInterval(dispatchInterval)
        }
        if let level = LogLevel(rawValue: json["log_level"].stringValue) {
            gai?.logger.logLevel = level.gaiLogLevel
        } else {
            gai?.logger.logLevel = .verbose
        }
    }
}
