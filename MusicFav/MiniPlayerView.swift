//
//  MiniPlayerView.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/29/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit

class MiniPlayerView: UIView {
    @IBOutlet weak var thumbImgView:   UIImageView!
    @IBOutlet weak var durationLabel:  UILabel!
    @IBOutlet weak var titleLabel:     UILabel!
    @IBOutlet weak var playButton:     UIButton!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var nextButton:     UIButton!
    var delegate:       MiniPlayerViewDelegate?
    private var _state: PlayerState = .Pause
    var state: PlayerState {
        get { return _state }
        set(newState) { _state = newState; updatePlayButton() }
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        baseInit()
    }
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        baseInit()
    }
    
    func baseInit() {
        let view = NSBundle.mainBundle().loadNibNamed("MiniPlayerView", owner:self, options:nil)[0] as UIView
        view.frame = self.bounds;
        view.autoresizingMask = UIViewAutoresizing.FlexibleWidth|UIViewAutoresizing.FlexibleHeight;
        self.addSubview(view)
        self.playButton.addTarget(    self, action: "playButtonTapped",     forControlEvents: UIControlEvents.TouchUpInside)
        self.previousButton.addTarget(self, action: "previousButtonTapped", forControlEvents: UIControlEvents.TouchUpInside)
        self.nextButton.addTarget(    self, action: "nextButtonTapped",     forControlEvents: UIControlEvents.TouchUpInside)
        
        let singleTap = UITapGestureRecognizer(target:self, action:"thumbnailImgTapped")
        singleTap.numberOfTapsRequired = 1;
        thumbImgView.userInteractionEnabled = true
        thumbImgView.addGestureRecognizer(singleTap)

        playButton.setImage(UIImage(named: "pause"), forState: UIControlState.Normal)
        self._state = .Pause
    }

    func updatePlayButton() {
        switch (state) {
        case .Pause:
            playButton.setImage(UIImage(named: "pause"), forState: UIControlState.Normal)
        case .Play:
            playButton.setImage(UIImage(named: "play"), forState: UIControlState.Normal)
        }
    }
    
    func playButtonTapped() {
        delegate?.miniPlayerViewPlayButtonTouched()
    }
    
    func previousButtonTapped() {
        delegate?.miniPlayerViewPreviousButtonTouched()
    }
    
    func nextButtonTapped() {
        delegate?.miniPlayerViewNextButtonTouched()
    }

    func thumbnailImgTapped() {
        delegate?.miniPlayerViewThumbImgTouched()
    }
}
