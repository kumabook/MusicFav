//
//  ControlPanel.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 9/13/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import PlayerKit
import MarqueeLabel

public class ControlPanel: PlayerKit.ControlPanel {
    let duration = 7.5
    override public func createSubviews() {
        super.createSubviews();
        titleLabel = MarqueeLabel(frame: titleLabel.frame, duration: duration, andFadeLength: 0)
    }
}
