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


protocol ControlPanelDelegate: class {
    func likeButtonTapped(sender: ControlPanel)
}

public class ControlPanel: PlayerKit.ControlPanel {
    let buttonSize:         CGFloat = 40.0
    let buttonPadding:      CGFloat = 30.0

    let duration = 7.5
    var likeButton: UIButton!
    weak var delegate: ControlPanelDelegate?
    override public func createSubviews() {
        super.createSubviews();
        titleLabel = MarqueeLabel(frame: titleLabel.frame, duration: duration, andFadeLength: 0)
        likeButton = UIButton(type: UIButtonType.System)
    }

    public override func initializeSubviews() {
        super.initializeSubviews()
        likeButton.tintColor = UIColor.whiteColor()
        likeButton.setImage(UIImage(named: "like"), forState: UIControlState())
        likeButton.addTarget(self, action: #selector(ControlPanel.like), forControlEvents: UIControlEvents.TouchUpInside)
        addSubview(likeButton)
    }

    public override func updateConstraints() {
        super.updateConstraints()
        likeButton.snp_makeConstraints { make in
            make.right.equalTo(self.previousButton.snp_left).offset(-self.buttonPadding)
            make.centerY.equalTo(self.previousButton.snp_centerY)
            make.width.equalTo(self.buttonSize)
            make.height.equalTo(self.buttonSize)
        }
    }

    func like() {
        delegate?.likeButtonTapped(self)
    }
}
