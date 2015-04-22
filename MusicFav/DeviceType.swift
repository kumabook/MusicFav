//
//  DeviceType.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/22/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

enum UIUserInterfaceIdiom : Int {
    case Unspecified
    case Phone
    case Pad
}

struct ScreenSize {
    static let SCREEN_WIDTH      = UIScreen.mainScreen().bounds.size.width
    static let SCREEN_HEIGHT     = UIScreen.mainScreen().bounds.size.height
    static let SCREEN_MAX_LENGTH = max(SCREEN_WIDTH, SCREEN_HEIGHT)
    static let SCREEN_MIN_LENGTH = min(SCREEN_WIDTH, SCREEN_HEIGHT)
}

enum DeviceType {
    case iPhone4OrLess
    case iPhone5
    case iPhone6
    case iPhone6Plus
    case iPad
    case Unknown
    static func from(#device: UIDevice) -> DeviceType {
        switch device.userInterfaceIdiom {
        case .Phone:
            if ScreenSize.SCREEN_MAX_LENGTH < 568.0 {
                return iPhone4OrLess
            } else if ScreenSize.SCREEN_MAX_LENGTH  == 568.0 {
                return iPhone5
            } else if ScreenSize.SCREEN_MAX_LENGTH  == 667.0 {
                return iPhone6
            } else if ScreenSize.SCREEN_MAX_LENGTH  == 736.0 {
                return iPhone6Plus
            }
        case .Pad:
            return iPad
        case .Unspecified:
            break
        }
        return Unknown
    }
}