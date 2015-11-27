//
//  UIColorExtension.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2/24/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

extension UIColor {
    private class func build(r r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) -> UIColor {
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    class var theme:       UIColor { return build(r: 240/255, g: 139/255, b:  51/255, a: 1.0) }
    class var themeLight:  UIColor { return build(r: 240/255, g: 139/255, b:  51/255, a: 0.8) }
    class var green:       UIColor { return build(r:  71/255, g: 234/255, b: 126/255, a: 1.0) }
    class var red:         UIColor { return build(r: 219/255, g:  36/255, b:  91/255, a: 1.0) }
    class var blue:        UIColor { return build(r: 100/255, g: 149/255, b: 237/255, a: 1.0) }
    class var transparent: UIColor { return build(r:       0, g:       0, b:       0, a:   0) }
    class var lightGray:   UIColor { return build(r: 214/255, g: 214/255, b: 214/255, a: 1.0) }
    class var slateGray:   UIColor { return build(r:       0, g:  51/255, b: 102/255, a: 0.5) }
    class var lightBlack:  UIColor { return build(r:       0, g:       0, b:       0, a: 0.7) }
    class var lightGreen:  UIColor { return build(r: 110/255, g: 234/255, b: 155/255, a: 1.0) }
    class var lightTheme:  UIColor { return build(r: 255/255, g: 160/255, b:  80/255, a: 0.8) }
    class var lightBlue:   UIColor { return build(r: 130/255, g: 180/255, b: 227/255, a: 1.0) }

}
