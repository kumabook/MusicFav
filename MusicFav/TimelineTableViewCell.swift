//
//  TimelineTableViewCell.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/23/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit

class TimelineTableViewCell: UITableViewCell {

    @IBOutlet weak var thumbImgView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    var rawImageView: UIImageView = UIImageView()

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}
