//
//  UIAlertControllerExtension.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/11/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

extension UIAlertController {
    class func show(vc: UIViewController, title: String, message: String, handler: (UIAlertAction!) -> Void) -> UIAlertController {
        let ac = UIAlertController(title: title,
            message: message,
            preferredStyle: UIAlertControllerStyle.Alert)
        let okAction = UIAlertAction(title: "OK".localize(), style: UIAlertActionStyle.Default, handler: handler)
        ac.addAction(okAction)
        vc.presentViewController(ac, animated: true, completion: nil)
        return ac
    }
}
