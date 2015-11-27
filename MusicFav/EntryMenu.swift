//
//  EntryMenu.swift
//  MusicFav
//
//  Created by KumamotoHiroki on 11/26/15.
//  Copyright © 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import SnapKit

public protocol EntryMenuDelegate: class {
    func entryMenuSelected(item: EntryMenu.MenuItem)
}

public class EntryMenu: UIButton {
    static let arrowHeight:     CGFloat = 16
    public class UpArrow: UIView {
        let h: CGFloat = 44
        var color: UIColor!
        init(color: UIColor) {
            self.color = color
            let frame = CGRect(x: 0, y: 0, width: arrowHeight, height: arrowHeight)
            super.init(frame: frame)
            backgroundColor = UIColor.transparent
        }

        required public init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }

        override public func drawRect(rect: CGRect) {
            let c = UIGraphicsGetCurrentContext()
            CGContextBeginPath(c)
            CGContextMoveToPoint(   c, CGRectGetMinX(rect), CGRectGetMaxY(rect))
            CGContextAddLineToPoint(c, CGRectGetMidX(rect), CGRectGetMinY(rect))
            CGContextAddLineToPoint(c, CGRectGetMaxX(rect), CGRectGetMaxY(rect))
            CGContextClosePath(c)
            var red:   CGFloat = 0
            var green: CGFloat = 0
            var blue:  CGFloat = 0
            var alpha: CGFloat = 0
            self.color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            CGContextSetRGBFillColor(c, red, green, blue, alpha)
            CGContextFillPath(c)
        }
    }
    let iconMargin: CGFloat               = 16
    let animationDuration: NSTimeInterval = 0.2
    let menuItemHeight: CGFloat           = 60
    var isAnimating: Bool = false
    var menuView: UIView!
    var upArrow:  UpArrow!
    var maxFrame: CGRect!
    var minFrame: CGRect!
    var items:    [MenuItem]!
    weak var delegate: EntryMenuDelegate?
    public enum MenuItem {
        case OpenWithSafari
        case Share
        case Favorite
        case SaveToFeedly

        var title: String {
            switch self {
            case OpenWithSafari: return "Open with Safari".localize()
            case Share:          return "Share the Entry".localize()
            case Favorite:       return "Favorite the Entry".localize()
            case SaveToFeedly:   return "Save to Feedly".localize()
            }
        }

        var icon: UIImage {
            switch self {
            case OpenWithSafari: return UIImage(named: "browser")!.imageWithRenderingMode(.AlwaysTemplate)
            case Share:          return UIImage(named: "share")!.imageWithRenderingMode(.AlwaysTemplate)
            case Favorite:       return UIImage(named: "fav_entry")!.imageWithRenderingMode(.AlwaysTemplate)
            case SaveToFeedly:   return UIImage(named: "saved")!.imageWithRenderingMode(.AlwaysTemplate)
            }
        }

        var normalColor: UIColor {
            switch self {
            case OpenWithSafari: return UIColor.blue
            case Share:          return UIColor.green
            case Favorite:       return UIColor.theme
            case SaveToFeedly:   return UIColor.blue
            }
        }
        var highlightedColor: UIColor {
            switch self {
            case OpenWithSafari: return UIColor.lightBlue
            case Share:          return UIColor.lightGreen
            case Favorite:       return UIColor.lightTheme
            case SaveToFeedly:   return UIColor.lightBlue
            }
        }
        var normalBackgroundImage:    UIImage { return MenuItem.imageWithColor(normalColor) }
        var highlightedBackgroundImage: UIImage { return MenuItem.imageWithColor(highlightedColor) }

        static func imageWithColor(color: UIColor) -> UIImage {
            let rect = CGRectMake(0.0, 0.0, 1.0, 1.0)
            UIGraphicsBeginImageContext(rect.size)
            let context = UIGraphicsGetCurrentContext()
            CGContextSetFillColorWithColor(context, color.CGColor)
            CGContextFillRect(context, rect)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return image
        }

    }


    init(frame: CGRect, items: [MenuItem]) {
        super.init(frame: frame)
        self.items = items
        let  h: CGFloat = CGFloat(items.count) * menuItemHeight
        let ch: CGFloat = h / CGFloat(items.count)
        let  w: CGFloat = frame.width
        maxFrame        = CGRect(x: 0, y: 0, width: w, height: h)
        minFrame        = CGRect(x: 0, y: -h, width: w, height: h)
        backgroundColor = UIColor.lightBlack
        menuView        = UIView(frame: CGRect(x: 0, y: 0, width: frame.width, height: h))
        menuView.backgroundColor = UIColor.themeLight
        addSubview(menuView)
        let iconSize: CGFloat = ch * 0.6
        for i in 0..<items.count {
            let item        = items[i]
            let itemView    = UIButton(frame: CGRect(x: 0, y: CGFloat(i) * ch, width: w, height: ch))
            let label       = UILabel(frame: CGRect(x: 0, y: 0, width: w, height: ch))
            label.text      = item.title
            label.textColor = UIColor.whiteColor()
            label.font      = UIFont.boldSystemFontOfSize(16)
            let iconView    = UIImageView(frame: CGRect(x: 0, y: 0, width: iconSize, height: iconSize))
            iconView.image  = item.icon
            iconView.tintColor = UIColor.whiteColor()
            itemView.addSubview(label)
            itemView.addSubview(iconView)
            itemView.addTarget(self, action: "menuSelected:", forControlEvents: UIControlEvents.TouchUpInside)
            itemView.setBackgroundImage(item.normalBackgroundImage, forState: UIControlState.Normal)
            itemView.setBackgroundImage(item.highlightedBackgroundImage, forState: UIControlState.Highlighted)
            itemView.tag = i
            menuView.addSubview(itemView)
            label.snp_updateConstraints { make in
                make.center.equalTo(itemView)
            }
            iconView.snp_updateConstraints { make in
                make.right.equalTo(label.snp_left).offset(-iconMargin)
                make.centerY.equalTo(itemView)
                make.width.equalTo(iconSize)
                make.height.equalTo(iconSize)
            }
        }
        addTarget(self, action: "hide", forControlEvents: UIControlEvents.TouchUpInside)
        upArrow = UpArrow(color: items[0].normalColor)
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public override var hidden: Bool {
        get {
            return super.hidden
        }
        set(newValue) {
            if newValue {
               menuView.frame = minFrame
            }
            super.hidden = newValue
        }
    }

    func showWithNavigationBar(navbar: UINavigationBar?) {
        if isAnimating { return }
        hidden      = false
        isAnimating = true
        if let nh = navbar?.frame.height {
            upArrow.center = CGPoint(x: frame.width - nh * 1.65 - EntryMenu.arrowHeight / 2,
                                     y: nh - EntryMenu.arrowHeight / 2 + 1)
        }

        UIView.animateWithDuration(animationDuration,
            delay: 0,
            options: UIViewAnimationOptions.CurveEaseInOut,
            animations: {
                self.menuView.frame = self.maxFrame
            }, completion: { finished in
                self.isAnimating = false
        })
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.15 * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue()) {
            navbar?.addSubview(self.upArrow)
        }
        superview?.bringSubviewToFront(self)
    }

    func hide() {
        if isAnimating { return }
        isAnimating = true
        UIView.animateWithDuration(animationDuration,
            delay: 0,
            options: UIViewAnimationOptions.CurveEaseInOut,
            animations: {
                self.menuView.frame = self.minFrame
            }, completion: { finished in
                self.hidden      = true
                self.isAnimating = false
        })
        upArrow.removeFromSuperview()
    }

    func menuSelected(sender: UIButton) {
        hide()
        delegate?.entryMenuSelected(items[sender.tag])
    }
}
