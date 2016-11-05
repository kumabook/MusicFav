//
//  OnpuRefreshControl.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/29/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import ISAlternativeRefreshControl

class OnpuRefreshControl: ISAlternativeRefreshControl, CAAnimationDelegate {
    enum AnimationState {
        case normal
        case animating
        case completing
        case completed
    }

    let margin: CGFloat = 15.0
    var imageView: UIImageView!
    var timer: Timer?
    var prog: CGFloat = 0
    var animationState: AnimationState = .normal

    override init(frame: CGRect) {
        super.init(frame: frame)
        let s                 = frame.size
        clipsToBounds         = false
        imageView             = UIImageView(image: UIImage(named: "loading_icon"))
        imageView.contentMode = UIViewContentMode.scaleAspectFit
        let height            = s.height * 0.65
        imageView.frame       = CGRect(x: 0, y: (s.height - height) / 2, width: s.width, height: height)
        addSubview(imageView)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func didChangeProgress() {
        switch refreshingState {
        case .normal:
            prog = (2.0 * progress).truncatingRemainder(dividingBy: 2.0)
            updateView()
        case .refreshing:
            break
        case .refreshed:
            break
         }
    }

    override func willChangeRefreshingState(_ refreshingState: ISRefreshingState) {
        switch refreshingState {
        case .normal:
            imageView.image = UIImage(named: "loading_icon")
            imageView.layer.removeAllAnimations()
            animationState = .normal
        case .refreshing:
            animationState = .animating
            startLayerAnimation(false)
        case .refreshed:
            animationState = .normal
        }
    }

    override func beginRefreshing() {
        super.beginRefreshing()
    }

    override func endRefreshing() {
        animationState = .completing
    }

    func startLayerAnimation(_ returnNormal: Bool) {
        let layer              = imageView.layer;
        let animation          = CABasicAnimation(keyPath: "transform.rotation")
        let fromValue          = M_PI*Double(prog)
        let toValue            = returnNormal ? (2*M_PI) : (fromValue + 2*M_PI)
        animation.duration     = 0.64 * (toValue - fromValue) / (2*M_PI)
        animation.repeatCount  = 0
        animation.beginTime    = CACurrentMediaTime()
        animation.autoreverses = false
        animation.fromValue    = NSNumber(value: Float(fromValue) as Float)
        animation.toValue      = NSNumber(value: Float(toValue) as Float)
        animation.isRemovedOnCompletion = false
        animation.fillMode     = kCAFillModeForwards
        animation.delegate     = self
        layer.add(animation , forKey:"rotate-animation")
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        switch animationState {
        case .normal:
            break
        case .animating:
            animationState = .completing
            startLayerAnimation(false)
        case .completing:
            startLayerAnimation(true)
            animationState = .completed
        case .completed:
            self.imageView.image = UIImage(named: "loading_icon_\(arc4random_uniform(4))")
            let startTime = DispatchTime.now() + Double(Int64(1.0 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            DispatchQueue.main.asyncAfter(deadline: startTime) {
                super.endRefreshing()
            }
        }
    }

    func updateView() {
        imageView.layer.transform = CATransform3DMakeAffineTransform(CGAffineTransform(rotationAngle: CGFloat(M_PI) * prog))
    }
}
