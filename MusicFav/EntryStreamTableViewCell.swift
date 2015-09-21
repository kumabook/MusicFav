//
//  StreamEntryTableViewCell.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/23/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import MCSwipeTableViewCell
import SnapKit
import FeedlyKit
import MusicFeeder

class EntryStreamTableViewCell: MCSwipeTableViewCell {
    let padding:       CGFloat   = 5.0
    let labelFontSize: CGFloat   = 20.0
    var swipeCellBackgroundColor = UIColor(red: 227/255, green: 227/255, blue: 227/255, alpha: 1.0)

    @IBOutlet weak var thumbImgView:     UIImageView!
    @IBOutlet weak var titleLabel:       UILabel!
    @IBOutlet weak var originTitleLabel: UILabel!
    @IBOutlet weak var dateLabel:        UILabel!

    var rawImageView: UIImageView = UIImageView()

    var markAsReadColor: UIColor {
        get { return UIColor.red }
    }
    var markAsUnreadColor: UIColor {
        get { return UIColor.green }
    }
    var markAsUnsavedColor: UIColor {
        get { return UIColor.blue }
    }
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    func imageView(markAs markAs: StreamLoader.RemoveMark) -> UIView {
        let view              = UIView()
        let label             = UILabel()
        let imageView         = UIImageView(image: UIImage(named: "checkmark"))
        label.text            = cellText(markAs)
        label.textColor       = UIColor.whiteColor()
        label.font            = UIFont.boldSystemFontOfSize(self.labelFontSize)
        imageView.contentMode = UIViewContentMode.Center

        view.addSubview(label)
        view.addSubview(imageView)

        label.snp_makeConstraints { make in
            make.right.equalTo(imageView.snp_left).offset(-self.padding)
            make.centerY.equalTo(view.snp_centerY)
        }
        imageView.snp_makeConstraints { make in
            make.centerX.equalTo(view.snp_centerX)
            make.centerY.equalTo(view.snp_centerY)
        }
        return view
    }

    func cellText(markAs: StreamLoader.RemoveMark) -> String {
        switch markAs {
        case .Read:   return "Mark as Read".localize()
        case .Unread: return "Mark as Unread".localize()
        case .Unsave: return "Mark as Unsaved".localize()
        }
    }

    var markAsReadImageView:    UIView { return imageView(markAs: .Read) }
    var markAsUnreadImageView:  UIView { return imageView(markAs: .Unread) }
    var markAsUnsavedImageView: UIView { return imageView(markAs: .Unsave) }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func prepareSwipeViews(markAs: StreamLoader.RemoveMark, onSwipe: (MCSwipeTableViewCell) -> Void) {
        if respondsToSelector("setSeparatorInset:") {
            separatorInset = UIEdgeInsetsZero
        }
        contentView.backgroundColor = UIColor.whiteColor()
        selectionStyle = .Gray
        defaultColor   = swipeCellBackgroundColor
        switch markAs {
        case .Read:
            setSwipeGestureWithView(markAsReadImageView,
                color: markAsReadColor,
                mode: .Switch,
                state: .State1) { (cell, state, mode) in }
            setSwipeGestureWithView(markAsReadImageView,
                color: markAsReadColor,
                mode: MCSwipeTableViewCellMode.Exit,
                state: MCSwipeTableViewCellState.State2) { (cell, state, mode) in
                    onSwipe(cell)
            }
        case .Unread:
            setSwipeGestureWithView(markAsUnreadImageView,
                color: markAsUnreadColor,
                mode: .Switch,
                state: .State1) { (cell, state, mode) in }
            setSwipeGestureWithView(markAsUnreadImageView,
                color: markAsUnreadColor,
                mode: MCSwipeTableViewCellMode.Exit,
                state: MCSwipeTableViewCellState.State2) { (cell, state, mode) in
                    onSwipe(cell)
            }
        case .Unsave:
            setSwipeGestureWithView(markAsUnsavedImageView,
                color: markAsUnsavedColor,
                mode: .Switch,
                state: .State1) { (cell, state, mode) in }
            setSwipeGestureWithView(markAsUnsavedImageView,
                color: markAsUnsavedColor,
                mode: MCSwipeTableViewCellMode.Exit,
                state: MCSwipeTableViewCellState.State2) { (cell, state, mode) in
                    onSwipe(cell)
            }
        }
    }
}
