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
    class func showPurchaseAlert(vc: UIViewController, title: String, message: String, handler: (UIAlertAction!) -> Void) -> UIAlertController {
        let ac = UIAlertController(title: "MusicFav", message: message, preferredStyle: .Alert)
        ac.addAction(UIAlertAction(title: "Purchase".localize(), style: .Default, handler: {action in
            if let appDelegate = UIApplication.sharedApplication().delegate as? AppDelegate {
                appDelegate.paymentManager?.viewController = vc
                appDelegate.paymentManager?.purchaseUnlockEverything()
            }
        }))
        ac.addAction(UIAlertAction(title: "Cancel".localize(), style: .Cancel, handler: {action in }))
        vc.presentViewController(ac, animated: true, completion: {})
        return ac
    }
}
