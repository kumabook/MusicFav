//
//  OnpuActivityIndicatorView.swift
//  MusicFav
//
//  Created by KumamotoHiroki on 10/10/15.
//  Copyright © 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

class OnpuIndicatorView: UIView, CAAnimationDelegate {
    let rotationKey = "rotationAnimation"
    let crossfadeKey = "crossfadeAnimation"
    let duration = 1.2 as Double
    static let animationImages = [UIImage(named: Color.normal.imageName)!,
                                  UIImage(named: Color.blue.imageName)!,
                                  UIImage(named: Color.green.imageName)!,
                                  UIImage(named: Color.cyan.imageName)!]
    enum State {
        case pause
        case animating
    }

    enum Color: Int {
        case normal      = 0
        case red         = 1
        case blue        = 2
        case green       = 3
        case cyan        = 4
        static let count: UInt32 = 5
        var imageName: String {
            switch self {
            case .normal: return "loading_icon"
            case .red:    return "loading_icon_0"
            case .blue:   return "loading_icon_1"
            case .green:  return "loading_icon_2"
            case .cyan:   return "loading_icon_3"
            }
        }
    }

    enum Animation: Int {
        case rotate      = 0
        case colorSwitch = 1
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
        self.init(frame: frame, animation: .rotate)
    }

    init(frame: CGRect, animation anim: Animation) {
        state            = .pause
        color            = .normal
        animation        = anim
        imageView        = UIImageView(image: UIImage(named: Color.blue.imageName))
        subImageView     = UIImageView(image: UIImage(named: Color.green.imageName))
        currentImageView = imageView
        super.init(frame: frame)
        isUserInteractionEnabled = false

        imageView.frame    = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        subImageView.frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)

        addSubview(imageView)
        addSubview(subImageView)
    }

    required init?(coder aDecoder: NSCoder) {
        state            = .pause
        color            = .normal
        animation        = .colorSwitch
        imageView        = UIImageView()
        subImageView     = UIImageView()
        currentImageView = imageView
        super.init(coder: aDecoder)
        addSubview(imageView)
        addSubview(subImageView)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with:event)
        if self == hitView {
            return nil
        }
        return super.hitTest(point, with: event)
    }

    func isAnimating() -> Bool {
        return state == .animating
    }

    func startAnimating() {
        startAnimating(animation)
    }

    func startAnimating(_ anim: Animation) {
        animation = anim
        state     = .animating
        switch animation {
        case .rotate:
            if let _ = currentImageView.layer.animation(forKey: rotationKey) {
                return
            }
            rotate()
            stopAnimatingCrossFade()
        case .colorSwitch:
            if let _ = currentImageView.layer.animation(forKey: crossfadeKey) {
                return
            }
            stopAnimatingRotate()
            fadeIn()
        }
    }

    func stopAnimating() {
        state = .pause
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

    func setColor(_ c: Color) {
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

    fileprivate func rotate() {
        imageView.image               = UIImage(named: color.imageName)
        subImageView.image            = UIImage(named: color.imageName)
        let rotationAnimation         = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.toValue     = NSNumber(value: Float(2.0 * Double.pi) as Float)
        rotationAnimation.duration    = duration
        rotationAnimation.isCumulative  = true
        rotationAnimation.repeatCount = Float.infinity
        layer.add(rotationAnimation, forKey: rotationKey)
    }

    fileprivate func fadeIn() {
        if !isAnimating() { return }
        changeColorAtRandom()
        imageView.layer.opacity       = 0.0
        subImageView.layer.opacity    = 0.0
        let animation                 = CABasicAnimation(keyPath: "opacity")
        animation.duration            = duration
        animation.fromValue           = 0.0
        animation.toValue             = 1.0
        animation.isRemovedOnCompletion = false
        animation.fillMode            = kCAFillModeBoth
        animation.delegate            = self
        isFadeIn                      = true
        currentImageView.layer.add(animation, forKey: crossfadeKey)
    }

    fileprivate func fadeOut() {
        if !isAnimating() { return }
        currentImageView.layer.opacity = 1.0
        let animation                  = CABasicAnimation(keyPath: "opacity")
        animation.duration             = duration
        animation.fromValue            = 1.0
        animation.toValue              = 0.0
        animation.isRemovedOnCompletion  = false
        animation.fillMode             = kCAFillModeBoth
        animation.delegate             = self
        isFadeIn                       = false
        currentImageView.layer.add(animation, forKey: crossfadeKey)
    }

    func animationDidStart(_ anim: CAAnimation) {
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if !flag || animation != .colorSwitch || !isAnimating() {
            return
        }
        if isFadeIn {
            fadeOut()
        } else {
            fadeIn()
        }
    }
}
