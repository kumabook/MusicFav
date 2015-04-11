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
        self.view.backgroundColor = UIColor.whiteColor()
        self.allowRightSwipe      = false

        switch UIDevice.currentDevice().userInterfaceIdiom {
        case .Phone:
            self.leftGapPercentage    = 0.8
            self.rightGapPercentage   = 0.8
        case .Pad:
            self.leftGapPercentage    = 0.4
            self.rightGapPercentage   = 0.4
        case .Unspecified:
            self.leftGapPercentage    = 0.8
            self.rightGapPercentage   = 0.8
        }
    }
    func showRightPanelAnimated(animated: Bool, completion: () -> Void) {
        showRightPanelAnimated(true)
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.3 * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue(), completion)
    }
}