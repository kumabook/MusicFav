//
//  UIAlertControllerExtension.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/11/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

extension UIAlertController {
    class func show(_ vc: UIViewController, title: String, message: String, handler: @escaping (UIAlertAction!) -> Void) -> UIAlertController {
        let ac = UIAlertController(title: title,
            message: message,
            preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "OK".localize(), style: UIAlertActionStyle.default, handler: handler)
        ac.addAction(okAction)
        vc.present(ac, animated: true, completion: nil)
        return ac
    }
    class func showPurchaseAlert(_ vc: UIViewController, title: String, message: String, handler: (UIAlertAction!) -> Void) -> UIAlertController {
        let ac = UIAlertController(title: "MusicFav", message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Purchase".localize(), style: .default, handler: {action in
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.paymentManager?.viewController = vc
                appDelegate.paymentManager?.purchaseUnlockEverything()
            }
        }))
        ac.addAction(UIAlertAction(title: "Cancel".localize(), style: .cancel, handler: {action in }))
        vc.present(ac, animated: true, completion: {})
        return ac
    }
}
