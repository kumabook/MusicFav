//
//  PlayerViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 3/1/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import AVFoundation
import Snap
import SDWebImage

class PlayerViewController: UIViewController, DraggableCoverViewControllerDelegate {
    let thumbnailWidth:  CGFloat = 75.0
    let thumbnailHeight: CGFloat = 60.0
    enum Mode {
        case FullScreen
        case Mini
    }
    class ModalPlayerObserver: PlayerObserver {
        let vc: PlayerViewController
        init(playerViewController: PlayerViewController) {
            vc = playerViewController
            super.init()
        }
        override func timeUpdated()      { vc.updateViews() }
        override func didPlayToEndTime() { vc.updateViews() }
        override func statusChanged()    { vc.updateViews() }
        override func trackChanged()     { vc.updateViews() }
        override func started()          { vc.enablePlayerView() }
        override func ended()            { vc.updateViews() }
    }

    let paddingSide        = 15.0
    let paddingBottom      = 15.0
    let paddingBottomTime  = 5.0
    let controlPanelHeight = 130.0
    let buttonSize         = 40.0
    let buttonPadding      = 30.0

    var controlPanel:        UIView!
    var slider:              UISlider!
    var previousButton:      UIButton!
    var playButton:          UIButton!
    var nextButton:          UIButton!
    var currentLabel:        UILabel!
    var totalLabel:          UILabel!
    var playerView:          PlayerView!

    var app:                 UIApplication { get { return UIApplication.sharedApplication() }}
    var appDelegate:         AppDelegate   { get { return app.delegate as AppDelegate }}
    var player:              Player<PlayerObserver>? { get { return appDelegate.player }}
    var currentPlaylist:     Playlist? { get { return player?.currentPlaylist }}
    var currentTrack:        Track?    { get { return player?.currentTrack }}
    var modalPlayerObserver: ModalPlayerObserver!
    var thumbnailView:       UIView { get { return playerView }}
    var containerView:       UIView { get { return self.view }}

    var parent:              DraggableCoverViewController?
    var mode:                Mode = .Mini

    override init() {
        super.init()
        modalPlayerObserver = ModalPlayerObserver(playerViewController: self)
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Close",
                                                           style: UIBarButtonItemStyle.Done,
                                                          target: self,
                                                          action: "close")
        view.backgroundColor   = UIColor.whiteColor()
        controlPanel           = UIView()
        currentLabel           = UILabel()
        totalLabel             = UILabel()
        slider                 = UISlider()
        nextButton             = UIButton()
        playButton             = UIButton()
        previousButton         = UIButton()
        playerView             = PlayerView()

        playerView.contentMode = UIViewContentMode.ScaleAspectFit
        slider.addTarget(self, action: "previewSeek", forControlEvents: UIControlEvents.ValueChanged)
        slider.addTarget(self, action: "stopSeek", forControlEvents: UIControlEvents.TouchUpInside)
        slider.addTarget(self, action: "cancelSeek", forControlEvents: UIControlEvents.TouchUpOutside)
        nextButton.setBackgroundImage(    UIImage(named: "next"),     forState: UIControlState.allZeros)
        playButton.setBackgroundImage(    UIImage(named: "play"),     forState: UIControlState.allZeros)
        previousButton.setBackgroundImage(UIImage(named: "previous"), forState: UIControlState.allZeros)
        nextButton.addTarget(    self, action: "next",     forControlEvents: UIControlEvents.TouchUpInside)
        playButton.addTarget(    self, action: "toggle",   forControlEvents: UIControlEvents.TouchUpInside)
        previousButton.addTarget(self, action: "previous", forControlEvents: UIControlEvents.TouchUpInside)
        playerView.addTarget(    self, action: "fullScreenOrToggle",   forControlEvents: UIControlEvents.TouchUpInside)
        view.addSubview(playerView)
        view.addSubview(controlPanel)
        controlPanel.backgroundColor = ColorHelper.themeColorLight
        controlPanel.addSubview(currentLabel)
        controlPanel.addSubview(totalLabel)
        controlPanel.addSubview(slider)
        controlPanel.addSubview(nextButton)
        controlPanel.addSubview(playButton)
        controlPanel.addSubview(previousButton)
        controlPanel.snp_makeConstraints { make in
            make.left.equalTo(self.view.snp_left)
            make.right.equalTo(self.view.snp_right)
            make.bottom.equalTo(self.view.snp_bottom)
            make.height.equalTo(self.controlPanelHeight)
        }
        currentLabel.snp_makeConstraints { make in
            make.left.equalTo(self.controlPanel.snp_left).with.offset(self.paddingSide)
            make.top.equalTo(self.controlPanel.snp_top).with.offset(self.paddingBottomTime)
        }
        totalLabel.snp_makeConstraints { make in
            make.right.equalTo(self.controlPanel.snp_right).with.offset(-self.paddingSide)
            make.top.equalTo(self.controlPanel.snp_top).with.offset(self.paddingBottomTime)
        }
        slider.snp_makeConstraints { make in
            make.left.equalTo(self.controlPanel.snp_left).with.offset(self.paddingSide)
            make.right.equalTo(self.controlPanel.snp_right).with.offset(-self.paddingSide)
            make.top.equalTo(self.currentLabel.snp_bottom).with.offset(self.paddingBottom)
        }
        previousButton.snp_makeConstraints { make in
            make.right.equalTo(self.playButton.snp_left).with.offset(-self.buttonPadding)
            make.centerY.equalTo(self.playButton.snp_centerY)
            make.width.equalTo(self.buttonSize)
            make.height.equalTo(self.buttonSize)
        }
        playButton.snp_makeConstraints { (make) -> () in
            make.centerX.equalTo(self.controlPanel.snp_centerX)
            make.top.equalTo(self.slider.snp_bottom).with.offset(self.paddingBottom)
            make.width.equalTo(self.buttonSize * 3/5)
            make.height.equalTo(self.buttonSize * 3/5)
        }
        nextButton.snp_makeConstraints { make in
            make.left.equalTo(self.playButton.snp_right).with.offset(self.buttonPadding)
            make.centerY.equalTo(self.playButton.snp_centerY)
            make.width.equalTo(self.buttonSize)
            make.height.equalTo(self.buttonSize)
        }
        updateViews()
        player?.addObserver(modalPlayerObserver)
        enablePlayerView()
    }

    func disablePlayerView() {
        playerView.player = nil
    }

    func enablePlayerView() {
        if let avPlayer = player?.avPlayer {
            playerView.player = avPlayer
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func next() {
        player?.next()
    }

    func previous() {
        player?.previous()
    }

    func setDraggableCoverView(parent: DraggableCoverViewController) {
        self.parent = parent
    }

    func minimizeCoverView(parent: DraggableCoverViewController) {
        view.clipsToBounds = true
        view.frame = CGRect(x: 0,
                            y: 0,
                        width: thumbnailWidth,
                       height: thumbnailHeight)
        playerView.snp_removeConstraints()
        playerView.snp_makeConstraints { (make) -> () in
            make.left.equalTo(self.view.snp_left)
            make.right.equalTo(self.view.snp_right)
            make.top.equalTo(self.view.snp_top)
            make.bottom.equalTo(self.view.snp_bottom)
            make.width.equalTo(self.view.snp_width)
        }
        updateViews()
        view.layoutIfNeeded()
    }

    func maximizeCoverView(parent: DraggableCoverViewController) {
        let f = parent.view.frame
        view.frame = CGRect(x: 0, y: 0, width: f.width, height: f.height)
        playerView.snp_removeConstraints()
        playerView.snp_makeConstraints { (make) -> () in
            make.left.equalTo(self.view.snp_left)
            make.right.equalTo(self.view.snp_right)
            make.top.equalTo(self.view.snp_top)
            make.bottom.equalTo(self.view.snp_bottom).offset(-self.thumbnailHeight)
            make.width.equalTo(self.view.snp_width)
        }
        updateViews()
        view.layoutIfNeeded()
    }

    func fullScreenOrToggle() {
        switch mode {
        case .FullScreen:
            mode = .Mini
            parent?.minimizeCoverView()
            updateViews()
        case .Mini:
            mode = .FullScreen
            parent?.maximizeCoverView()
            updateViews()
        }
    }

    func toggle() {
        player?.toggle()
    }

    func previewSeek() {
        if slider.tracking {
            CMTimeMakeWithSeconds(Float64(slider.value), 1)
            updateViewsOfTime(current: slider.value, total: slider.maximumValue)
        }
        if let state = player?.currentState {
            if state == .Pause {
                player?.seekToTime(CMTimeMakeWithSeconds(Float64(slider.value), 1))
            }
        }
    }

    func stopSeek() {
        if let _player = player {
            _player.seekToTime(CMTimeMakeWithSeconds(Float64(slider.value), 1))
        }
    }

    func cancelSeek() {
        if let _player = player {
            updateViews()
        }
    }

    func updateViews() {
        switch mode {
        case .FullScreen:
            controlPanel.hidden   = false
            currentLabel.hidden   = false
            totalLabel.hidden     = false
            slider.hidden         = false
            nextButton.hidden     = false
            previousButton.hidden = false
            view.bringSubviewToFront(controlPanel)
        case .Mini:
            controlPanel.hidden   = true
            currentLabel.hidden   = true
            totalLabel.hidden     = true
            slider.hidden         = true
            nextButton.hidden     = true
            previousButton.hidden = true
            view.bringSubviewToFront(playerView)
        }
        if let state = player?.currentState {
            switch (state) {
            case .Play:
                playButton.setBackgroundImage(UIImage(named: "play"), forState: UIControlState.allZeros)
            case .Pause:
                playButton.setBackgroundImage(UIImage(named: "pause"), forState: UIControlState.allZeros)
            }
        }
        if let track = currentTrack {
            navigationItem.title = track.title
            if let avPlayer = player?.avPlayer {
                playerView.sd_setBackgroundImageWithURL(nil, forState: UIControlState.allZeros)
            } else {
                playerView.sd_setBackgroundImageWithURL(track.thumbnailUrl, forState: UIControlState.allZeros)
            }
        } else {
            totalLabel.text   = "00:00"
            currentLabel.text = "00:00"
            playerView.sd_setBackgroundImageWithURL(nil, forState: UIControlState.allZeros)
        }
        if let (current, total) = player?.secondPair {
            if !slider.tracking { updateViewsOfTime(current: current, total: total) }
        }
    }

    func updateViewsOfTime(#current: Float64, total: Float64) {
        updateViewsOfTime(current: Float(current), total: Float(total))
    }

    func updateViewsOfTime(#current: Float, total: Float) {
        if total > 0 {
            currentLabel.text   = TimeHelper.timeStr(current)
            totalLabel.text     = TimeHelper.timeStr(total)
            slider.value        = Float(current)
            slider.maximumValue = Float(total)
        } else {
            currentLabel.text   = "00:00"
            totalLabel.text     = "00:00"
            slider.value        = 0
            slider.maximumValue = 0
        }
    }

    func close() {
        navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }
}
