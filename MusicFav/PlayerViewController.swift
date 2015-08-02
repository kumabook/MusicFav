//
//  PlayerViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 3/1/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import iAd
import AVFoundation
import Snap
import SDWebImage
import MarqueeLabel
import MusicFeeder

class PlayerViewController: UIViewController, DraggableCoverViewControllerDelegate, ADBannerViewDelegate {
    let minThumbnailWidth:  CGFloat = 75.0
    let minThumbnailHeight: CGFloat = 60.0

    class ModalPlayerObserver: PlayerObserver {
        let vc: PlayerViewController
        init(playerViewController: PlayerViewController) {
            vc = playerViewController
            super.init()
        }
        override func timeUpdated()               { vc.updateViews() }
        override func didPlayToEndTime()          { vc.updateViews() }
        override func statusChanged()             { vc.updateViews() }
        override func trackSelected(track: PlayerKitTrack, index: Int, playlist: PlayerKitPlaylist) {
            vc.updateViews()
        }
        override func trackUnselected(track: PlayerKitTrack, index: Int, playlist: PlayerKitPlaylist) {
            vc.updateViews()
        }
    }

    let paddingSide:        CGFloat = 10.0
    let paddingBottom:      CGFloat = 15.0
    let paddingBottomTime:  CGFloat = 5.0
    let controlPanelHeight: CGFloat = 130.0
    let buttonSize:         CGFloat = 40.0
    let buttonPadding:      CGFloat = 30.0

    var controlPanel:        UIView!
    var slider:              UISlider!
    var previousButton:      UIButton!
    var playButton:          UIButton!
    var nextButton:          UIButton!
    var titleLabel:          MarqueeLabel!
    var currentLabel:        UILabel!
    var totalLabel:          UILabel!
    var playerView:          PlayerView!
    var adBannerView:        ADBannerView?

    var app:                 UIApplication { get { return UIApplication.sharedApplication() }}
    var appDelegate:         AppDelegate   { get { return app.delegate as! AppDelegate }}
    var player:              Player<PlayerObserver>? { get { return appDelegate.player }}
    var currentPlaylist:     Playlist? { get { return player?.currentPlaylist as? Playlist }}
    var currentTrack:        Track?    { get { return player?.currentTrack as? Track }}
    var modalPlayerObserver: ModalPlayerObserver!
    var thumbnailView:       UIView { get { return playerView }}

    var draggableCoverViewController: DraggableCoverViewController?

    init() {
        super.init(nibName: nil, bundle: nil)
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
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Close".localize(),
                                                           style: UIBarButtonItemStyle.Done,
                                                          target: self,
                                                          action: "close")
        view.backgroundColor   = UIColor.blackColor()
        controlPanel           = UIView()
        titleLabel             = MarqueeLabel(frame: CGRect(), duration: 8.0, andFadeLength: 10.0)
        currentLabel           = UILabel()
        totalLabel             = UILabel()
        slider                 = UISlider()
        nextButton             = UIButton.buttonWithType(UIButtonType.System) as! UIButton
        playButton             = UIButton.buttonWithType(UIButtonType.System) as! UIButton
        previousButton         = UIButton.buttonWithType(UIButtonType.System) as! UIButton
        playerView             = PlayerView()

        titleLabel.textColor     = UIColor.whiteColor()
        titleLabel.font          = UIFont.boldSystemFontOfSize(16)
        titleLabel.textColor     = UIColor.whiteColor()
        titleLabel.textAlignment = NSTextAlignment.Center
        currentLabel.textColor   = UIColor.whiteColor()
        currentLabel.font        = UIFont.boldSystemFontOfSize(15)
        totalLabel.textColor     = UIColor.whiteColor()
        totalLabel.font          = UIFont.boldSystemFontOfSize(15)

        nextButton.tintColor     = UIColor.whiteColor()
        playButton.tintColor     = UIColor.whiteColor()
        previousButton.tintColor = UIColor.whiteColor()

        playerView.imageView?.contentMode = UIViewContentMode.ScaleAspectFit
        playerView.setImage(UIImage(named: "default_thumb"), forState: UIControlState.allZeros)
        slider.addTarget(self, action: "previewSeek", forControlEvents: UIControlEvents.ValueChanged)
        slider.addTarget(self, action: "stopSeek", forControlEvents: UIControlEvents.TouchUpInside)
        slider.addTarget(self, action: "cancelSeek", forControlEvents: UIControlEvents.TouchUpOutside)
        nextButton.setImage(    UIImage(named: "next"),     forState: UIControlState.allZeros)
        playButton.setImage(    UIImage(named: "play"),     forState: UIControlState.allZeros)
        previousButton.setImage(UIImage(named: "previous"), forState: UIControlState.allZeros)
        nextButton.addTarget(    self, action: "next",         forControlEvents: UIControlEvents.TouchUpInside)
        playButton.addTarget(    self, action: "toggle",       forControlEvents: UIControlEvents.TouchUpInside)
        previousButton.addTarget(self, action: "previous",     forControlEvents: UIControlEvents.TouchUpInside)
        playerView.addTarget(    self, action: "toggleScreen", forControlEvents: UIControlEvents.TouchUpInside)
        view.addSubview(playerView)
        view.addSubview(controlPanel)
        controlPanel.backgroundColor = UIColor.darkGrayColor()
        controlPanel.clipsToBounds = true
        controlPanel.addSubview(titleLabel)
        controlPanel.addSubview(currentLabel)
        controlPanel.addSubview(totalLabel)
        controlPanel.addSubview(slider)
        controlPanel.addSubview(nextButton)
        controlPanel.addSubview(playButton)
        controlPanel.addSubview(previousButton)
        resizeViews(0.0)

        currentLabel.snp_makeConstraints { make in
            make.left.equalTo(self.controlPanel.snp_left).with.offset(self.paddingSide).priorityHigh()
            make.top.equalTo(self.controlPanel.snp_top).with.offset(self.paddingBottomTime)
        }
        totalLabel.snp_makeConstraints { make in
            make.right.equalTo(self.controlPanel.snp_right).with.offset(-self.paddingSide).priorityHigh()
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
        titleLabel.snp_makeConstraints { make in
            make.left.greaterThanOrEqualTo(self.controlPanel.snp_left).offset(self.paddingSide*6)
            make.right.greaterThanOrEqualTo(self.controlPanel.snp_right).offset(-self.paddingSide*6)
            make.centerX.equalTo(self.controlPanel.snp_centerX)
            make.top.equalTo(self.controlPanel.snp_top).with.offset(self.paddingBottomTime)
            make.bottom.equalTo(self.slider.snp_top).with.offset(self.paddingBottomTime)
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
            if playerView.player != avPlayer {
                playerView.player = avPlayer
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func toggle() {
        Logger.sendUIActionEvent(self, action: "toggle", label: "")
        player?.toggle()
    }

    func next() {
        Logger.sendUIActionEvent(self, action: "next", label: "")
        player?.next()
    }

    func previous() {
        Logger.sendUIActionEvent(self, action: "previous", label: "")
        player?.previous()
    }

    func didMinimizedCoverView() {
        Logger.sendUIActionEvent(self, action: "didMinimizedCoverView", label: "")
        updateViews()
        removeAdView()
    }

    func didMaximizedCoverView() {
        Logger.sendUIActionEvent(self, action: "didMaximizedCoverView", label: "")
        updateViews()
        addAdView()
        showAdView()
    }

    func didResizeCoverView(rate: CGFloat) {
        resizeViews(rate)
    }

    func resizeViews(rate: CGFloat) {
        let  f = view.frame
        var ch = controlPanelHeight * rate
        var  h = f.height - ch
        if let pf = draggableCoverViewController?.view.frame {
            playerView.frame     = CGRect(x: 0, y: 0, width:  f.width, height: h)
            controlPanel.frame   = CGRect(x: 0, y: h, width: pf.width, height: ch)
            view.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: rate)
            controlPanel.alpha   = rate
        }
        hideAdView()
    }

    func toggleScreen() {
        Logger.sendUIActionEvent(self, action: "toggleScreen", label: "")
        draggableCoverViewController?.toggleScreen()
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
        Logger.sendUIActionEvent(self, action: "stopSeek", label: "")
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
        enablePlayerView()
        if let state = player?.currentState {
            if state.isPlaying {
                playButton.setImage(UIImage(named: "pause"), forState: UIControlState.allZeros)
            } else {
                playButton.setImage(UIImage(named: "play"), forState: UIControlState.allZeros)
            }
        }
        if let track = currentTrack {
            titleLabel.text = track.title
            if let url = track.thumbnailUrl {
                playerView.sd_setImageWithURL(url, forState: UIControlState.allZeros)
            } else {
                playerView.setImage(UIImage(named: "note"), forState: UIControlState.allZeros)
            }
        } else {
            totalLabel.text   = "00:00"
            currentLabel.text = "00:00"
            playerView.setImage(UIImage(named: "note"), forState: UIControlState.allZeros)
        }
        if let (current, total) = player?.secondPair {
            if !slider.tracking { updateViewsOfTime(current: Float(current), total: Float(total)) }
        }
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

    func addAdView() {
        if adBannerView == nil {
            let adView = ADBannerView()
            adView.delegate = self
            adView.alpha = 0.0
            view.addSubview(adView)
            adView.snp_makeConstraints { make in
                make.left.equalTo(self.view.snp_left)
                make.right.equalTo(self.view.snp_right)
                make.top.equalTo(self.view.snp_top)
            }
            adBannerView = adView
        }
    }

    func removeAdView() {
        if let adView = adBannerView {
            adView.delegate = nil
            adView.removeFromSuperview()
            adBannerView = nil
        }
    }

    func showAdView() { if let adView = adBannerView { adView.hidden = false } }
    func hideAdView() { if let adView = adBannerView { adView.hidden = true } }

    // MARK: - ADBannerViewDelegate

    func bannerViewDidLoadAd(banner: ADBannerView!) {
        adBannerView?.alpha = 1.0
    }

    func bannerView(banner: ADBannerView!, didFailToReceiveAdWithError error: NSError!) {
        removeAdView()
    }
}
