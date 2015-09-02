//
//  StreamTreeViewCell.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/15/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import SnapKit

class StreamTreeViewCell: UITableViewCell {
    let thumbWidth: CGFloat = 32
    let margin:     CGFloat = 12
    let perWidth:   Int = 24
    var indent:     Int = 0

    override func layoutSubviews() {
        super.layoutSubviews()
        self.imageView?.contentMode = UIViewContentMode.ScaleAspectFit
        if let f = self.imageView?.frame {
            self.imageView?.frame = CGRect(x: f.origin.x , y: f.origin.y, width: thumbWidth, height: f.height)
        }
        self.imageView?.move(x: CGFloat(indent * perWidth), y: 0)
        let imageRect = self.imageView!.frame
        let labelRect = self.textLabel!
        self.textLabel?.frame = CGRect(x: imageRect.origin.x + imageRect.width + margin,
                                       y: imageRect.origin.y,
                                   width: labelRect.frame.width,
                                  height: labelRect.frame.height)
    }
}
