//
//  TrackTableViewCell.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/28/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit

class TrackTableViewCell: UITableViewCell {

    @IBOutlet weak var thumbImgView:     UIImageView!
    @IBOutlet weak var trackNameLabel:   UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
    }

}
