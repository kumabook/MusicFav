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
    fileprivate class func createCompletedHUD(_ view: UIView) -> MBProgressHUD {
        let hud = MBProgressHUD(view: view)
        hud.customView = UIImageView(image:UIImage(named:"checkmark"))
        hud.mode = MBProgressHUDMode.customView
        hud.label.text = "Completed".localize()
        return hud
    }

    class func showHUDForView(_ view: UIView, message: String, animated: Bool, duration: TimeInterval, after: @escaping () -> Void) -> MBProgressHUD {
        let hud = MBProgressHUD(view: view)
        hud.label.text = message
        return hud.show(view, animated: animated, duration: duration, after: after)
    }

    class func showCompletedHUDForView(_ view: UIView, animated: Bool, duration: TimeInterval, after: @escaping () -> Void) -> MBProgressHUD {
        let hud = MBProgressHUD.createCompletedHUD(view)
        return hud.show(view, animated: animated, duration: duration, after: after)
    }

    fileprivate func show(_ view: UIView, animated: Bool, duration: TimeInterval, after: @escaping () -> Void) -> MBProgressHUD {
        view.addSubview(self)
        self.show(true, duration: duration, after: {
            self.removeFromSuperview()
            after()
        })
        return self
    }

    func show(_ animated:Bool, duration:TimeInterval, after:@escaping () -> Void) {
        show(animated: true)
        let startTime = DispatchTime.now() + Double(Int64(duration * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: startTime) { () -> Void in
            self.hide(animated: true)
            after()
        }
    }
}
