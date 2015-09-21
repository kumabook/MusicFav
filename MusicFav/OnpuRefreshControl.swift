//
//  OnpuRefreshControl.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/29/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import ISAlternativeRefreshControl

class OnpuRefreshControl: ISAlternativeRefreshControl {
    enum AnimationState {
        case Normal
        case Animating
        case Completing
        case Completed
    }

    let margin: CGFloat = 15.0
    var imageView: UIImageView!
    var timer: NSTimer?
    var prog: CGFloat = 0
    var animationState: AnimationState = .Normal

    override init(frame: CGRect) {
        super.init(frame: frame)
        let s                 = frame.size
        clipsToBounds         = false
        imageView             = UIImageView(image: UIImage(named: "loading_icon"))
        imageView.contentMode = UIViewContentMode.ScaleAspectFit
        let height            = s.height * 0.65
        imageView.frame       = CGRect(x: 0, y: (s.height - height) / 2, width: s.width, height: height)
        addSubview(imageView)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func didChangeProgress() {
        switch refreshingState {
        case .Normal:
            prog = (2.0 * progress) % 2.0
            updateView()
        case .Refreshing:
            break
        case .Refreshed:
            break
         }
    }

    override func willChangeRefreshingState(refreshingState: ISRefreshingState) {
        switch refreshingState {
        case .Normal:
            imageView.image = UIImage(named: "loading_icon")
            imageView.layer.removeAllAnimations()
            animationState = .Normal
        case .Refreshing:
            animationState = .Animating
            startLayerAnimation(false)
        case .Refreshed:
            animationState = .Normal
        }
    }

    override func beginRefreshing() {
        super.beginRefreshing()
    }

    override func endRefreshing() {
        animationState = .Completing
    }

    func startLayerAnimation(returnNormal: Bool) {
        let layer              = imageView.layer;
        let animation          = CABasicAnimation(keyPath: "transform.rotation")
        let fromValue          = M_PI*Double(prog)
        let toValue            = returnNormal ? (2*M_PI) : (fromValue + 2*M_PI)
        animation.duration     = 0.64 * (toValue - fromValue) / (2*M_PI)
        animation.repeatCount  = 0
        animation.beginTime    = CACurrentMediaTime()
        animation.autoreverses = false
        animation.fromValue    = NSNumber(float: Float(fromValue))
        animation.toValue      = NSNumber(float: Float(toValue))
        animation.removedOnCompletion = false
        animation.fillMode     = kCAFillModeForwards
        animation.delegate     = self
        layer.addAnimation(animation , forKey:"rotate-animation")
    }

    override func animationDidStop(anim: CAAnimation, finished flag: Bool) {
        switch animationState {
        case .Normal:
            break
        case .Animating:
            animationState = .Completing
            startLayerAnimation(false)
        case .Completing:
            startLayerAnimation(true)
            animationState = .Completed
        case .Completed:
            self.imageView.image = UIImage(named: "loading_icon_\(arc4random_uniform(4))")
            let startTime = dispatch_time(DISPATCH_TIME_NOW, Int64(1.0 * Double(NSEC_PER_SEC)))
            dispatch_after(startTime, dispatch_get_main_queue()) {
                super.endRefreshing()
            }
        }
    }

    func updateView() {
        imageView.layer.transform = CATransform3DMakeAffineTransform(CGAffineTransformMakeRotation(CGFloat(M_PI) * prog))
    }
}
