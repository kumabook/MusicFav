//
//  MiniPlayerViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/28/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import AVFoundation
import JASidePanels
import MediaPlayer

class MiniPlayerViewController: UIViewController, MiniPlayerViewDelegate {
    class MiniPlayerObserver: PlayerObserver {
        let vc: MiniPlayerViewController
        init(miniPlayerViewController: MiniPlayerViewController) {
            vc = miniPlayerViewController
            super.init()
        }
        override func timeUpdated()      { vc.updateViews() }
        override func didPlayToEndTime() { vc.updateViews() }
        override func statusChanged()    { vc.updateViews() }
        override func trackChanged()     { vc.updateViews() }
        override func started()          { vc.updateViews() }
        override func ended()            { vc.updateViews() }
    }
    var mainViewController:          JASidePanelController!
    var timelineViewController:      TimelineTableViewController!
    var playlistTableViewController: PlaylistTableViewController!
    var menuViewController:          MenuTableViewController!
    var currentPlaylist:             Playlist? { get { return player?.currentPlaylist }}
    var currentTrack:                Track?    { get { return player?.currentTrack }}
    var miniPlayerObserver:          MiniPlayerObserver!
    var app:                         UIApplication { get { return UIApplication.sharedApplication() }}
    var appDelegate:                 AppDelegate   { get { return app.delegate as AppDelegate }}
    var player:                      Player<PlayerObserver>? { get { return appDelegate.player }}
    @IBOutlet weak var mainViewContainer: UIView!
    @IBOutlet weak var miniPlayerView:    MiniPlayerView!

    override init() {
        super.init(nibName: "MiniPlayerViewController", bundle: NSBundle.mainBundle())
        mainViewController                      = JASidePanelController()
        timelineViewController                  = TimelineTableViewController(stream: nil)
        playlistTableViewController             = PlaylistTableViewController()
        menuViewController                      = MenuTableViewController()
        mainViewController.leftPanel            = UINavigationController(rootViewController:menuViewController)
        mainViewController.rightPanel           = UINavigationController(rootViewController:playlistTableViewController)
        mainViewController.centerPanel          = UINavigationController(rootViewController:timelineViewController)
        mainViewController.view.backgroundColor = UIColor.whiteColor()
        mainViewController.allowRightSwipe      = false
        miniPlayerObserver                      = MiniPlayerObserver(miniPlayerViewController: self)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
    }
    
    override func loadView() {
        super.loadView()
        miniPlayerView.delegate = self
        mainViewContainer.addSubview(mainViewController.view)
        mainViewController.view.frame = mainViewContainer.bounds
        view.bringSubviewToFront(miniPlayerView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateViews()
        player?.addObserver(miniPlayerObserver)
    }

    override func viewWillDisappear(animated: Bool) {
        miniPlayerView.playerView.player = AVPlayer()
    }

    override func viewWillAppear(animated: Bool) {
        if let avPlayer = player?.avPlayer { miniPlayerView.playerView.player = avPlayer }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func updateViews() {
        if let track = currentTrack {
            let playingInfoCenter: AnyClass? = NSClassFromString("MPNowPlayingInfoCenter")
            if let center: AnyClass = playingInfoCenter {
                var info:[String:AnyObject]                           = [:]
                info[MPMediaItemPropertyTitle]                        = track.title
                MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = info
            }
            miniPlayerView.titleLabel.text = track.title
            if let (current, total) = player?.secondPair {
                miniPlayerView.durationLabel.text = TimeHelper.timeStr(Float(current))
            } else {
                miniPlayerView.durationLabel.text = "00:00"
            }
            self.miniPlayerView.playerView.sd_setBackgroundImageWithURL(track.thumbnailUrl,
                forState: UIControlState.allZeros,
               completed: { (image, error, cacheType, url) -> Void in
                let playingInfoCenter: AnyClass? = NSClassFromString("MPNowPlayingInfoCenter")
                if let center: AnyClass = playingInfoCenter {
                    let albumArt                                          = MPMediaItemArtwork(image:image)
                    var info:[String:AnyObject]                           = [:]
                    info[MPMediaItemPropertyTitle]                        = track.title
                    info[MPMediaItemPropertyArtwork]                      = albumArt
                    MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = info
                }
            })
        } else {
            MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = nil
            miniPlayerView.titleLabel.text    = "no track"
            miniPlayerView.durationLabel.text = "00:00"
            miniPlayerView.playerView.setBackgroundImage(nil, forState: UIControlState.allZeros)
        }
        miniPlayerView.state = player!.currentState
    }
    
    func showOAuthViewController() {
        let oauthvc = FeedlyOAuthViewController(nibName:"FeedlyOAuthViewController", bundle:NSBundle.mainBundle())
        let vc = UINavigationController(rootViewController: oauthvc)
        self.presentViewController(vc, animated: true, nil)
    }
    
    func showMenu() {
        appDelegate.miniPlayerViewController?.mainViewController.showLeftPanelAnimated(true)
    }

    func showPlaylist() {
        appDelegate.miniPlayerViewController?.mainViewController.showRightPanelAnimated(true)
    }
    
    func play(index: Int, playlist: Playlist) {
        player?.play(index, playlist: playlist)
        if let avPlayer = player?.avPlayer { miniPlayerView.playerView.player = avPlayer }
    }

    // MARK: - MiniPlayerViewDelegate -
    
    func miniPlayerViewPlayButtonTouched() {
        player?.toggle()
    }
    
    func miniPlayerViewPreviousButtonTouched() {
        player?.previous()
    }
    
    func miniPlayerViewNextButtonTouched() {
        player?.next()
    }
    
    func miniPlayerViewThumbImgTouched() {
        if let track = player?.currentTrack {
            let pvc = PlayerViewController()
            pvc.playerView = miniPlayerView.playerView
            presentViewController(UINavigationController(rootViewController: pvc), animated: true, completion: nil)
        }
    }
}
