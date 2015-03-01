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
    var player:                      Player<PlayerObserver>?
    var currentPlaylist:             Playlist? { get { return player?.currentPlaylist }}
    var currentTrack:                Track?    { get { return player?.currentTrack }}
    var miniPlayerObserver:          MiniPlayerObserver!
    
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
        player                                  = Player()
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
            if let currentSec = player?.currentSec {
                let str = NSString(format:"%02d:%02d", Int(floor(currentSec / 60)), Int(floor(currentSec % 60)))
                miniPlayerView.durationLabel.text = str
            } else {
                miniPlayerView.durationLabel.text = "00:00"
            }

            self.miniPlayerView.thumbImgView.sd_setImageWithURL(track.thumbnailUrl, completed: { (image, error, cacheType, url) -> Void in
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
            miniPlayerView.thumbImgView.sd_setImageWithURL(nil)
        }
        miniPlayerView.state = player!.currentState
    }
    
    func showOAuthViewController() {
        let oauthvc = FeedlyOAuthViewController(nibName:"FeedlyOAuthViewController", bundle:NSBundle.mainBundle())
        let vc = UINavigationController(rootViewController: oauthvc)
        self.presentViewController(vc, animated: true, nil)
    }
    
    func showMenu() {
        let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        appDelegate.miniPlayerViewController?.mainViewController.showLeftPanelAnimated(true)
    }

    func showPlaylist() {
        let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        appDelegate.miniPlayerViewController?.mainViewController.showRightPanelAnimated(true)
    }
    
    func play(index: Int, playlist: Playlist) {
        player?.play(index, playlist: playlist)
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
        }
    }
}
