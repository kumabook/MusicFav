//
//  MiniPlayerView.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 9/12/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import PlayerKit
import MarqueeLabel

open class MiniPlayerView: PlayerKit.SimpleMiniPlayerView {
    let duration = 7.5
    override open func createSubviews() {
        super.createSubviews();
        titleLabel = MarqueeLabel(frame: titleLabel.frame, duration: duration, andFadeLength: 0)
    }
}
