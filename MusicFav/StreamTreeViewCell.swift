//
//  StreamTreeViewCell.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/15/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

class StreamTreeViewCell: UITableViewCell {
    let perWidth: Int = 24
    var indent:   Int = 0
    override func layoutSubviews() {
        super.layoutSubviews()
        self.imageView?.move(x: CGFloat(indent * perWidth), y: 0)
        self.textLabel?.move(x: CGFloat(indent * perWidth), y: 0)
    }
}
