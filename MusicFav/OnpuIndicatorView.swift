//
//  OnpuActivityIndicatorView.swift
//  MusicFav
//
//  Created by KumamotoHiroki on 10/10/15.
//  Copyright © 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

class OnpuIndicatorView: UIImageView {
    let duration = 1.2 as Double
    static let animationImages = [UIImage(named: Color.Normal.imageName)!,
                                  UIImage(named: Color.Blue.imageName)!,
                                  UIImage(named: Color.Green.imageName)!,
                                  UIImage(named: Color.Cyan.imageName)!]
    enum State {
        case Pause
        case Animating
    }

    enum Color: Int {
        case Normal      = 0
        case Red         = 1
        case Blue        = 2
        case Green       = 3
        case Cyan        = 4
        static let count = 5
        var imageName: String {
            switch self {
            case Normal: return "loading_icon"
            case Red:    return "loading_icon_0"
            case Blue:   return "loading_icon_1"
            case Green:  return "loading_icon_2"
            case Cyan:   return "loading_icon_3"
            }
        }
    }

    enum Animation: Int {
        case Rotate      = 0
        case ColorSwitch = 1
        func random() -> Animation {
            return Animation(rawValue: Int(arc4random_uniform(2)))!
        }
    }

    var state:     State
    var color:     Color
    var animation: Animation

    override convenience init(frame: CGRect) {
        self.init(frame: frame, animation: .Rotate)
    }

    init(frame: CGRect, animation: Animation) {
        state          = .Pause
        color          = .Normal
        self.animation = animation
        super.init(frame: frame)
        image          = UIImage(named: Color.Normal.imageName)!
        userInteractionEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        state     = .Pause
        color     = .Normal
        animation = .ColorSwitch
        super.init(coder: aDecoder)
    }

    override func hitTest(point: CGPoint, withEvent event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, withEvent:event)
        if self == hitView {
            return nil
        }
        return super.hitTest(point, withEvent: event)
    }

    override func isAnimating() -> Bool {
        return state == .Animating
    }

    override func startAnimating() {
        startAnimating(self.animation)
    }

    func startAnimating(animation: Animation) {
        self.animation                    = animation
        state                             = .Animating
        image                             = UIImage(named: color.imageName)
        switch animation {
        case .Rotate:
            super.stopAnimating()
            let rotationAnimation         = CABasicAnimation(keyPath: "transform.rotation.z")
            rotationAnimation.toValue     = NSNumber(float: Float(2.0 * M_PI))
            rotationAnimation.duration    = duration
            rotationAnimation.cumulative  = true
            rotationAnimation.repeatCount = Float.infinity
            layer.addAnimation(rotationAnimation, forKey: "rotationAnimation")
        case .ColorSwitch:
            layer.removeAllAnimations()
            animationDuration    = duration
            animationRepeatCount = 0
            animationImages      = OnpuIndicatorView.animationImages
            super.startAnimating()
        }
    }

    override func stopAnimating() {
        if !isAnimating() { return }
        state = .Pause
        layer.removeAllAnimations()
        super.stopAnimating()
    }

    func setColor(color: Color) {
        self.color = color
        image = UIImage(named: color.imageName)
    }
}
