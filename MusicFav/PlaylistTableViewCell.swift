//
//  PlaylistTableViewCell.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2/7/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

class PlaylistTableViewCell: UITableViewCell {
    @IBOutlet weak var thumbImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var trackNumLabel: UILabel!
    let leftMarginPercent: CGFloat = 0.2

    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.constraints.filter { $0.identifier == "left_margin" }.forEach {
            print("constance \($0.constant) to \(self.frame.width * leftMarginPercent)")
            $0.constant = self.frame.width * leftMarginPercent
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
