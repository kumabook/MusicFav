//
//  HUDExtension.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2/19/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import MBProgressHUD

extension MBProgressHUD {
    class func createCompletedHUD(view: UIView) -> MBProgressHUD {
        let HUD = MBProgressHUD(view: view)
        HUD.customView = UIImageView(image:UIImage(named:"checkmark"))
        HUD.mode = MBProgressHUDMode.CustomView
        HUD.labelText = "Completed";
        return HUD
    }

    func show(animated:Bool, duration:NSTimeInterval, after:() -> Void) {
        show(true)
        let startTime = dispatch_time(DISPATCH_TIME_NOW, Int64(duration * Double(NSEC_PER_SEC)))
        dispatch_after(startTime, dispatch_get_main_queue()) { () -> Void in
            self.hide(true)
            after()
        }
    }
}