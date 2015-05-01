//
//  GAIConfig.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 5/1/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import SwiftyJSON

public class GAIConfig {
    enum LogLevel: String {
        case None    = "none"
        case Error   = "error"
        case Warning = "warning"
        case Info    = "info"
        case Verbose = "verbose"
        var gaiLogLevel: GAILogLevel {
            switch self {
            case None:    return GAILogLevel.None
            case Error:   return GAILogLevel.Error
            case Warning: return GAILogLevel.Warning
            case Info:    return GAILogLevel.Info
            case Verbose: return GAILogLevel.Verbose
            }
        }
    }
    public class func setup(filePath: String) {
        var gai                     = GAI.sharedInstance()
        let data                    = NSData(contentsOfFile: filePath)
        let jsonObject: AnyObject?  = NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers, error: nil)
        let json                    = JSON(jsonObject!)
        
        if let trackerId = json["tracker_id"].string {
            gai.trackerWithTrackingId(trackerId)
        }

        gai.trackUncaughtExceptions = true;
        if let dispatchInterval = json["dispatch_inverval"].int {
            gai.dispatchInterval = NSTimeInterval(dispatchInterval)
        }
        if let level = LogLevel(rawValue: json["log_level"].stringValue) {
            gai.logger.logLevel = level.gaiLogLevel
        } else {
            gai.logger.logLevel = .Verbose
        }
    }
}