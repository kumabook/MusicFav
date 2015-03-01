//
//  TimelineTableViewCell.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/23/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import MCSwipeTableViewCell

class TimelineTableViewCell: MCSwipeTableViewCell {
    var swipeCellBackgroundColor = UIColor(red: 227/255, green: 227/255, blue: 227/255, alpha: 1.0)
    var markAsSavedColor: UIColor {
        get { return ColorHelper.greenColor }
    }
    var markAsReadColor: UIColor {
        get { return ColorHelper.redColor }
    }
    var markAsSavedImageView: UIView {
        get {
            var imageView = UIImageView(image: UIImage(named: "pin"))
            imageView.contentMode = UIViewContentMode.Center
            return imageView
        }
    }
    var markAsReadImageView: UIView {
        get {
            var imageView = UIImageView(image: UIImage(named: "checkmark"))
            imageView.contentMode = UIViewContentMode.Center
            return imageView
        }
    }

    @IBOutlet weak var thumbImgView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    var rawImageView: UIImageView = UIImageView()

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func prepareSwipeViews(#onMarkAsSaved: (MCSwipeTableViewCell) -> Void, onMarkAsRead: (MCSwipeTableViewCell) -> Void) {
        if respondsToSelector("setSeparatorInset:") {
            separatorInset = UIEdgeInsetsZero
        }
        contentView.backgroundColor = UIColor.whiteColor()
        selectionStyle = .Gray
        defaultColor   = swipeCellBackgroundColor
        setSwipeGestureWithView(markAsSavedImageView,
            color: markAsSavedColor,
            mode: .Switch,
            state: .State1) { (cell, state, mode) in }
        setSwipeGestureWithView(markAsSavedImageView,
            color: markAsSavedColor,
            mode: MCSwipeTableViewCellMode.Exit,
            state: MCSwipeTableViewCellState.State2) { (cell, state, mode) in
                onMarkAsSaved(cell)
        }
        setSwipeGestureWithView(markAsReadImageView,
            color: markAsReadColor,
            mode: .Switch,
            state: .State3) { (cell, state, mode) in }
        setSwipeGestureWithView(markAsReadImageView,
            color: markAsReadColor,
            mode: MCSwipeTableViewCellMode.Exit,
            state: MCSwipeTableViewCellState.State4) { (cell, state, mode) in
                onMarkAsRead(cell)
        }
    }
}
