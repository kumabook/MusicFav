//
//  AnimatedLaunchScreen.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 11/23/16.
//  Copyright © 2016 Hiroki Kumamoto. All rights reserved.
//

import Foundation

class AnimatedLaunchScreen: UIView, CAAnimationDelegate {
    enum AnimationState {
        case initial
        case zoomOut
        case zoomIn
        case finish
    }
    let size = CGSize(width: 100, height: 95)
    private var state = AnimationState.initial
    private var scale: CGFloat = 1.0
    weak var icon: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.theme
        addSubviews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.backgroundColor = UIColor.theme
        addSubviews()
    }

    private func addSubviews() {
        let icon = UIImageView(image: UIImage(named: "icon"))
        icon.bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        icon.center = self.center
        icon.move(x: 0, y: -20)
        self.icon = icon
        self.addSubview(icon)
    }
    
    func startAnimation(superView: UIView) {
        superView.addSubview(self)
        animate(scale: 1.0, duration: 0.4)
    }
    private func animate(scale: CGFloat, duration: CGFloat) {
        let layer              = icon.layer;
        let animation          = CABasicAnimation(keyPath: "transform.scale")
        animation.duration     = CFTimeInterval(duration)
        animation.repeatCount  = 0
        animation.beginTime    = CACurrentMediaTime()
        animation.autoreverses = false
        animation.fromValue    = NSNumber(value: Float(self.scale))
        animation.toValue      = NSNumber(value: Float(scale))
        animation.isRemovedOnCompletion = false
        animation.fillMode     = kCAFillModeForwards
        animation.delegate     = self
        layer.add(animation, forKey:"scale-animation")
        self.scale = scale
    }
    
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        switch state {
        case .initial:
            animate(scale: 0.8, duration: 0.1)
            state = .zoomOut
        case .zoomOut:
            animate(scale: 1.2, duration: 0.1)
            state = .zoomIn
        case .zoomIn:
            animate(scale: 1.0, duration: 0.1)
            state = .finish
        case .finish:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.removeFromSuperview()
            }
        }
    }
}
