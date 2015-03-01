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

class PlayerViewController: UIViewController {
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
        override func started()          { vc.updateViews() }
        override func ended()            { vc.updateViews() }
    }

    let paddingSide        = 15.0
    let paddingBottom      = 30.0
    let paddingBottomTime  = 5.0
    let controlPanelHeight = 80

    var controlPanel:       UIView!
    var slider:             UISlider!
    var previousButton:     UIButton!
    var nextButton:         UIButton!
    var currentLabel:       UILabel!
    var totalLabel:         UILabel!
    var playerView:         PlayerView!

    var app:                UIApplication { get { return UIApplication.sharedApplication() }}
    var appDelegate:        AppDelegate   { get { return app.delegate as AppDelegate }}
    var player:             Player<PlayerObserver>? { get { return appDelegate.player }}
    var currentPlaylist:    Playlist? { get { return player?.currentPlaylist }}
    var currentTrack:       Track?    { get { return player?.currentTrack }}
    var modalPlayerObserver: ModalPlayerObserver!

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
        previousButton         = UIButton()
        playerView             = PlayerView()

        playerView.contentMode = UIViewContentMode.ScaleAspectFit
        slider.addTarget(self, action: "previewSeek", forControlEvents: UIControlEvents.ValueChanged)
        slider.addTarget(self, action: "stopSeek", forControlEvents: UIControlEvents.TouchUpInside)
        slider.addTarget(self, action: "cancelSeek", forControlEvents: UIControlEvents.TouchUpOutside)
        nextButton.setBackgroundImage(    UIImage(named: "next"),     forState: UIControlState.allZeros)
        previousButton.setBackgroundImage(UIImage(named: "previous"), forState: UIControlState.allZeros)
        nextButton.addTarget(    self, action: "next",     forControlEvents: UIControlEvents.TouchUpInside)
        previousButton.addTarget(self, action: "previous", forControlEvents: UIControlEvents.TouchUpInside)
        playerView.addTarget(    self, action: "toggle",   forControlEvents: UIControlEvents.TouchUpInside)
        view.addSubview(controlPanel)
        view.addSubview(playerView)
        controlPanel.backgroundColor = ColorHelper.themeColorLight
        controlPanel.addSubview(currentLabel)
        controlPanel.addSubview(totalLabel)
        controlPanel.addSubview(slider)
        controlPanel.addSubview(nextButton)
        controlPanel.addSubview(previousButton)
        controlPanel.snp_makeConstraints { make in
            make.left.equalTo(self.view.snp_left)
            make.right.equalTo(self.view.snp_right)
            make.bottom.equalTo(self.view.snp_bottom)
            make.height.equalTo(self.controlPanelHeight)
        }
        currentLabel.snp_makeConstraints { make in
            make.left.equalTo(self.controlPanel.snp_left).with.offset(self.paddingSide)
            make.bottom.equalTo(self.controlPanel.snp_bottom).with.offset(-self.paddingBottomTime)
        }
        totalLabel.snp_makeConstraints { make in
            make.right.equalTo(self.controlPanel.snp_right).with.offset(-self.paddingSide)
            make.bottom.equalTo(self.controlPanel.snp_bottom).with.offset(-self.paddingBottomTime)
        }
        slider.snp_makeConstraints { make in
            make.left.equalTo(self.previousButton.snp_right).with.offset(self.paddingSide)
            make.right.equalTo(self.nextButton.snp_left).with.offset(-self.paddingSide)
            make.bottom.equalTo(self.controlPanel.snp_bottom).with.offset(-self.paddingBottom)
        }
        previousButton.snp_makeConstraints { make in
            make.left.equalTo(self.controlPanel.snp_left).with.offset(self.paddingSide)
            make.bottom.equalTo(self.controlPanel.snp_bottom).with.offset(-self.paddingBottom)
        }
        nextButton.snp_makeConstraints { make in
            make.right.equalTo(self.controlPanel.snp_right).with.offset(-self.paddingSide)
            make.bottom.equalTo(self.controlPanel.snp_bottom).with.offset(-self.paddingBottom)
        }
        playerView.snp_makeConstraints { (make) -> () in
            make.left.equalTo(self.view.snp_left)
            make.right.equalTo(self.view.snp_right)
            make.top.equalTo(self.view.snp_top)
            make.bottom.equalTo(self.controlPanel.snp_top)
            make.width.equalTo(self.view.snp_width)
        }
        updateViews()
        player?.addObserver(modalPlayerObserver)
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
        if let track = currentTrack {
            navigationItem.title = track.title
            if let avPlayer = player?.avPlayer {
                playerView.player = avPlayer
                playerView.sd_setBackgroundImageWithURL(nil, forState: UIControlState.allZeros)
            } else {
                playerView.sd_setBackgroundImageWithURL(track.thumbnailUrl, forState: UIControlState.allZeros)
            }
        } else {
            totalLabel.text = "00:00"
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
