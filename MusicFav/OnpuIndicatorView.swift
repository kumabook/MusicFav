//
//  OnpuActivityIndicatorView.swift
//  MusicFav
//
//  Created by KumamotoHiroki on 10/10/15.
//  Copyright © 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

class OnpuIndicatorView: UIView {
    let rotationKey = "rotationAnimation"
    let crossfadeKey = "crossfadeAnimation"
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
        static let count: UInt32 = 5
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

    var state:            State
    var color:            Color
    var animation:        Animation
    var imageView:        UIImageView
    var subImageView:     UIImageView
    var currentImageView: UIImageView
    var isFadeIn: Bool = false

    override convenience init(frame: CGRect) {
        self.init(frame: frame, animation: .Rotate)
    }

    init(frame: CGRect, animation anim: Animation) {
        state            = .Pause
        color            = .Normal
        animation        = anim
        imageView        = UIImageView(image: UIImage(named: Color.Blue.imageName))
        subImageView     = UIImageView(image: UIImage(named: Color.Green.imageName))
        currentImageView = imageView
        super.init(frame: frame)
        userInteractionEnabled = false

        imageView.frame    = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        subImageView.frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)

        addSubview(imageView)
        addSubview(subImageView)
    }

    required init?(coder aDecoder: NSCoder) {
        state            = .Pause
        color            = .Normal
        animation        = .ColorSwitch
        imageView        = UIImageView()
        subImageView     = UIImageView()
        currentImageView = imageView
        super.init(coder: aDecoder)
        addSubview(imageView)
        addSubview(subImageView)
    }

    override func hitTest(point: CGPoint, withEvent event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, withEvent:event)
        if self == hitView {
            return nil
        }
        return super.hitTest(point, withEvent: event)
    }

    func isAnimating() -> Bool {
        return state == .Animating
    }

    func startAnimating() {
        startAnimating(animation)
    }

    func startAnimating(anim: Animation) {
        animation = anim
        state     = .Animating
        switch animation {
        case .Rotate:
            if let _ = currentImageView.layer.animationForKey(rotationKey) {
                return
            }
            rotate()
            stopAnimatingCrossFade()
        case .ColorSwitch:
            if let _ = currentImageView.layer.animationForKey(crossfadeKey) {
                return
            }
            stopAnimatingRotate()
            fadeIn()
        }
    }

    func stopAnimating() {
        state = .Pause
        stopAnimatingRotate()
        stopAnimatingCrossFade()
    }

    func stopAnimatingRotate() {
        layer.removeAllAnimations()
    }

    func stopAnimatingCrossFade() {
        imageView.layer.removeAllAnimations()
        subImageView.layer.removeAllAnimations()
        imageView.layer.opacity    = 1.0
        subImageView.layer.opacity = 1.0
    }

    func setColor(c: Color) {
        color = c
        currentImageView.image = UIImage(named: color.imageName)
    }

    func changeColorAtRandom() {
        if let color = Color(rawValue: Int(arc4random_uniform(Color.count))) {
            setColor(color)
        }
    }

    func replaceImageView() {
        currentImageView = currentImageView == imageView ? subImageView : imageView
    }

    private func rotate() {
        imageView.image               = UIImage(named: color.imageName)
        subImageView.image            = UIImage(named: color.imageName)
        let rotationAnimation         = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.toValue     = NSNumber(float: Float(2.0 * M_PI))
        rotationAnimation.duration    = duration
        rotationAnimation.cumulative  = true
        rotationAnimation.repeatCount = Float.infinity
        layer.addAnimation(rotationAnimation, forKey: rotationKey)
    }

    private func fadeIn() {
        if !isAnimating() { return }
        changeColorAtRandom()
        imageView.layer.opacity       = 0.0
        subImageView.layer.opacity    = 0.0
        let animation                 = CABasicAnimation(keyPath: "opacity")
        animation.duration            = duration
        animation.fromValue           = 0.0
        animation.toValue             = 1.0
        animation.removedOnCompletion = false
        animation.fillMode            = kCAFillModeBoth
        animation.delegate            = self
        isFadeIn                      = true
        currentImageView.layer.addAnimation(animation, forKey: crossfadeKey)
    }

    private func fadeOut() {
        if !isAnimating() { return }
        currentImageView.layer.opacity = 1.0
        let animation                  = CABasicAnimation(keyPath: "opacity")
        animation.duration             = duration
        animation.fromValue            = 1.0
        animation.toValue              = 0.0
        animation.removedOnCompletion  = false
        animation.fillMode             = kCAFillModeBoth
        animation.delegate             = self
        isFadeIn                       = false
        currentImageView.layer.addAnimation(animation, forKey: crossfadeKey)
    }

    override func animationDidStart(anim: CAAnimation) {
    }

    override func animationDidStop(anim: CAAnimation, finished flag: Bool) {
        if !flag || animation != .ColorSwitch || !isAnimating() {
            return
        }
        if isFadeIn {
            fadeOut()
        } else {
            fadeIn()
        }
    }
}
