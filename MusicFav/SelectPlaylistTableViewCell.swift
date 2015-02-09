//
//  SelectPlaylistTableViewCell.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2/9/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

class SelectPlaylistTableViewCell: UITableViewCell {
    @IBOutlet weak var thumbImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var trackNumLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
