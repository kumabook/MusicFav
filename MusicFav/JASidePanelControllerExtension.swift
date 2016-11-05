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
        view.backgroundColor = UIColor.white
        allowLeftSwipe       = true
        allowRightSwipe      = true

        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            leftGapPercentage    = 0.8
            rightGapPercentage   = 0.8
        case .pad:
            leftGapPercentage    = 0.4
            rightGapPercentage   = 0.4
        case .unspecified:
            leftGapPercentage    = 0.8
            rightGapPercentage   = 0.8
        case .tv:
            leftGapPercentage    = 0.8
            rightGapPercentage   = 0.8
        default:
            break
        }
    }
    func showRightPanelAnimated(_ animated: Bool, completion: @escaping () -> Void) {
        showRightPanel(animated: true)
        let delayTime = DispatchTime.now() + Double(Int64(0.3 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: delayTime, execute: completion)
    }
}
