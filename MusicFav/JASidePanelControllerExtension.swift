//
//  JASidePanelControllerExtension.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/11/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import JASidePanels

extension JASidePanelController {
    func prepare() {
        view.backgroundColor = UIColor.whiteColor()
        allowLeftSwipe       = true
        allowRightSwipe      = true

        switch UIDevice.currentDevice().userInterfaceIdiom {
        case .Phone:
            leftGapPercentage    = 0.8
            rightGapPercentage   = 0.8
        case .Pad:
            leftGapPercentage    = 0.4
            rightGapPercentage   = 0.4
        case .Unspecified:
            leftGapPercentage    = 0.8
            rightGapPercentage   = 0.8
        case .TV:
            leftGapPercentage    = 0.8
            rightGapPercentage   = 0.8
        default:
            break
        }
    }
    func showRightPanelAnimated(animated: Bool, completion: () -> Void) {
        showRightPanelAnimated(true)
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.3 * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue(), completion)
    }
}