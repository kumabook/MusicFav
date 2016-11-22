//
//  TrackTableViewCell.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/28/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import SnapKit

class TrackTableViewCell: UITableViewCell {

    @IBOutlet weak var thumbImgView:   UIImageView!
    @IBOutlet weak var trackNameLabel: UILabel!
    @IBOutlet weak var durationLabel:  UILabel!
    let leftMarginPercent: CGFloat = 0.05
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.constraints.filter { $0.identifier == "left_margin" }.forEach {
            $0.constant = self.frame.width * leftMarginPercent
        }
    }
}
