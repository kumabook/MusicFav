//
//  StreamEntryTableViewCell.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/23/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import MCSwipeTableViewCell
import Snap

class EntryStreamTableViewCell: MCSwipeTableViewCell {
    let padding:       CGFloat   = 5.0
    let labelFontSize: CGFloat   = 20.0
    var swipeCellBackgroundColor = UIColor(red: 227/255, green: 227/255, blue: 227/255, alpha: 1.0)
    var markAsSavedColor: UIColor {
        get { return ColorHelper.greenColor }
    }
    var markAsReadColor: UIColor {
        get { return ColorHelper.redColor }
    }
/*
    var markAsSavedImageView: UIView {
        get {
            let view              = UIView()
            let label             = UILabel()
            let imageView         = UIImageView(image: UIImage(named: "pin"))
            label.text            = "Mark as Save".localize()
            label.textColor       = UIColor.whiteColor()
            label.font            = UIFont.boldSystemFontOfSize(self.labelFontSize)
            imageView.contentMode = UIViewContentMode.Center
            
            view.addSubview(label)
            view.addSubview(imageView)
            
            label.snp_makeConstraints { make in
                make.right.equalTo(imageView.snp_left).with.offset(-self.padding)
                make.centerY.equalTo(view.snp_centerY)
            }
            imageView.snp_makeConstraints { make in
                make.centerX.equalTo(view.snp_centerX)
                make.centerY.equalTo(view.snp_centerY)
            }
            return view
        }
    }
*/
    var markAsReadImageView: UIView {
        get {
            let view              = UIView()
            let label             = UILabel()
            let imageView         = UIImageView(image: UIImage(named: "checkmark"))
            label.text            = "Mark as Read".localize()
            label.textColor       = UIColor.whiteColor()
            label.font            = UIFont.boldSystemFontOfSize(self.labelFontSize)
            imageView.contentMode = UIViewContentMode.Center

            view.addSubview(label)
            view.addSubview(imageView)

            label.snp_makeConstraints { make in
                make.right.equalTo(imageView.snp_left).with.offset(-self.padding)
                make.centerY.equalTo(view.snp_centerY)
            }
            imageView.snp_makeConstraints { make in
                make.centerX.equalTo(view.snp_centerX)
                make.centerY.equalTo(view.snp_centerY)
            }
            return view
        }
    }

    @IBOutlet weak var thumbImgView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var trackNumLabel: UILabel!
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
/*
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
*/
        setSwipeGestureWithView(markAsReadImageView,
            color: markAsReadColor,
             mode: .Switch,
            state: .State1) { (cell, state, mode) in }
        setSwipeGestureWithView(markAsReadImageView,
            color: markAsReadColor,
             mode: MCSwipeTableViewCellMode.Exit,
            state: MCSwipeTableViewCellState.State2) { (cell, state, mode) in
                onMarkAsRead(cell)
        }
    }
}
