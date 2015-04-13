//
//  StreamTableViewCell.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/13/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

class StreamTableViewCell: UITableViewCell {

    @IBOutlet weak var thumbImageView: UIImageView!
    @IBOutlet weak var titleLabel:     UILabel!
    @IBOutlet weak var subtitle1Label: UILabel!
    @IBOutlet weak var subtitle2Label: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func updateView(blog: Blog) {
        if let imageUrl = blog.blogImageSmall {
            thumbImageView.sd_setImageWithURL(NSURL(string: imageUrl))
        }
        titleLabel.text         = blog.siteName
        if let totalTracks = blog.totalTracks {
            subtitle1Label.text = "\(totalTracks) tracks"
        }
        if let followers = blog.followers {
            subtitle2Label.text = "\(followers) followers"
        }
    }
}
