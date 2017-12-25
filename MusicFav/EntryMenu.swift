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
    func entryMenuSelected(_ item: EntryMenu.MenuItem)
}

open class EntryMenu: UIButton {
    static let arrowHeight:     CGFloat = 16
    open class UpArrow: UIView {
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

        override open func draw(_ rect: CGRect) {
            let c = UIGraphicsGetCurrentContext()
            c?.beginPath()
            c?.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            c?.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            c?.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            c?.closePath()
            var red:   CGFloat = 0
            var green: CGFloat = 0
            var blue:  CGFloat = 0
            var alpha: CGFloat = 0
            self.color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            c?.setFillColor(red: red, green: green, blue: blue, alpha: alpha)
            c?.fillPath()
        }
    }
    let iconMargin: CGFloat               = 16
    let animationDuration: TimeInterval = 0.2
    let menuItemHeight: CGFloat           = 60
    var isAnimating: Bool = false
    var menuView: UIView!
    var upArrow:  UpArrow!
    var maxFrame: CGRect!
    var minFrame: CGRect!
    var items:    [MenuItem]!
    weak var delegate: EntryMenuDelegate?
    public enum MenuItem {
        case openWithSafari
        case share
        case favorite
        case saveToFeedly

        var title: String {
            switch self {
            case .openWithSafari: return "Open with Safari".localize()
            case .share:          return "Share the Entry".localize()
            case .favorite:       return "Favorite the Entry".localize()
            case .saveToFeedly:   return "Save to Feedly".localize()
            }
        }

        var icon: UIImage {
            switch self {
            case .openWithSafari: return UIImage(named: "browser")!.withRenderingMode(.alwaysTemplate)
            case .share:          return UIImage(named: "share")!.withRenderingMode(.alwaysTemplate)
            case .favorite:       return UIImage(named: "fav_entry")!.withRenderingMode(.alwaysTemplate)
            case .saveToFeedly:   return UIImage(named: "saved")!.withRenderingMode(.alwaysTemplate)
            }
        }

        var normalColor: UIColor {
            switch self {
            case .openWithSafari: return UIColor.blue
            case .share:          return UIColor.green
            case .favorite:       return UIColor.theme
            case .saveToFeedly:   return UIColor.blue
            }
        }
        var highlightedColor: UIColor {
            switch self {
            case .openWithSafari: return UIColor.lightBlue
            case .share:          return UIColor.lightGreen
            case .favorite:       return UIColor.lightTheme
            case .saveToFeedly:   return UIColor.lightBlue
            }
        }
        var normalBackgroundImage:    UIImage { return MenuItem.imageWithColor(normalColor) }
        var highlightedBackgroundImage: UIImage { return MenuItem.imageWithColor(highlightedColor) }

        static func imageWithColor(_ color: UIColor) -> UIImage {
            let rect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
            UIGraphicsBeginImageContext(rect.size)
            let context = UIGraphicsGetCurrentContext()
            context?.setFillColor(color.cgColor)
            context?.fill(rect)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return image!
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
            label.textColor = UIColor.white
            label.font      = UIFont.boldSystemFont(ofSize: 16)
            let iconView    = UIImageView(frame: CGRect(x: 0, y: 0, width: iconSize, height: iconSize))
            iconView.image  = item.icon
            iconView.tintColor = UIColor.white
            itemView.addSubview(label)
            itemView.addSubview(iconView)
            itemView.addTarget(self, action: #selector(EntryMenu.menuSelected(_:)), for: UIControlEvents.touchUpInside)
            itemView.setBackgroundImage(item.normalBackgroundImage, for: UIControlState())
            itemView.setBackgroundImage(item.highlightedBackgroundImage, for: UIControlState.highlighted)
            itemView.tag = i
            menuView.addSubview(itemView)
            label.snp.updateConstraints { make in
                make.center.equalTo(itemView)
            }
            iconView.snp.updateConstraints { make in
                make.right.equalTo(label.snp.left).offset(-iconMargin)
                make.centerY.equalTo(itemView)
                make.width.equalTo(iconSize)
                make.height.equalTo(iconSize)
            }
        }
        addTarget(self, action: #selector(EntryMenu.hide), for: UIControlEvents.touchUpInside)
        upArrow = UpArrow(color: items[0].normalColor)
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    open override var isHidden: Bool {
        get {
            return super.isHidden
        }
        set(newValue) {
            if newValue {
               menuView.frame = minFrame
            }
            super.isHidden = newValue
        }
    }

    func showWithNavigationBar(_ navbar: UINavigationBar?) {
        if isAnimating { return }
        isHidden      = false
        isAnimating = true
        if let nh = navbar?.frame.height {
            upArrow.center = CGPoint(x: frame.width - nh * 1.65 - EntryMenu.arrowHeight / 2,
                                     y: nh - EntryMenu.arrowHeight / 2 + 1)
        }

        UIView.animate(withDuration: animationDuration,
            delay: 0,
            options: UIViewAnimationOptions(),
            animations: {
                self.menuView.frame = self.maxFrame
            }, completion: { finished in
                self.isAnimating = false
        })
        let delayTime = DispatchTime.now() + Double(Int64(0.15 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: delayTime) {
            navbar?.addSubview(self.upArrow)
        }
        superview?.bringSubview(toFront: self)
    }

    @objc func hide() {
        if isAnimating { return }
        isAnimating = true
        UIView.animate(withDuration: animationDuration,
            delay: 0,
            options: UIViewAnimationOptions(),
            animations: {
                self.menuView.frame = self.minFrame
            }, completion: { finished in
                self.isHidden      = true
                self.isAnimating = false
        })
        upArrow.removeFromSuperview()
    }

    @objc func menuSelected(_ sender: UIButton) {
        hide()
        delegate?.entryMenuSelected(items[sender.tag])
    }
}
