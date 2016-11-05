//
//  AddStreamMenuTableViewCell.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/14/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

class AddStreamMenuTableViewCell: UITableViewCell {
    let thumbWidth: Int = 66
    let thumbMaxNum: Int = 5
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var thumbListContainer: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    fileprivate func clearThumbListContainer() {
        for v in thumbListContainer.subviews {
            v.removeFromSuperview()
        }
    }

    func setThumbnailImages(_ urls: [URL]) {
        clearThumbListContainer()
        let tw = thumbWidth
        for i in 0..<min(urls.count, thumbMaxNum) {
            let iv = UIImageView(frame: CGRect(x: i*tw, y: 0, width: tw, height: tw))
            thumbListContainer.addSubview(iv)
            iv.sd_setImage(with: urls[i], placeholderImage: UIImage(named: "default_thumb"))
        }
    }

    func setMessageLabel(_ message: String) {
        clearThumbListContainer()
        let messageLabel = UILabel(frame: thumbListContainer.frame)
        messageLabel.text = "You can subscribe YouTube channel.".localize()
        thumbListContainer.addSubview(messageLabel)
    }
}
