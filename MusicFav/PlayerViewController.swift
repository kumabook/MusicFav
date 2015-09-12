//
//  PlayerViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/12/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import PlayerKit

class PlayerViewController: PlayerKit.PlayerViewController {
    override var thumbImage: UIImage {
        return UIImage(named: "note")!
    }
    override func createSubviews() {
        super.createSubviews()
        controlPanel = ControlPanel()
    }
}
