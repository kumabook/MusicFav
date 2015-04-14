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
import SDWebImage

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
    var streamPageMenuController:    StreamPageMenuController!
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
        streamPageMenuController                = StreamPageMenuController(stream:  StreamLoader.defaultStream())
        playlistTableViewController             = PlaylistTableViewController()
        menuViewController                      = MenuTableViewController()
        mainViewController.leftPanel            = UINavigationController(rootViewController:menuViewController)
        mainViewController.rightPanel           = UINavigationController(rootViewController:playlistTableViewController)
        mainViewController.centerPanel          = UINavigationController(rootViewController:streamPageMenuController)

        mainViewController.prepare()
        miniPlayerObserver                      = MiniPlayerObserver(miniPlayerViewController: self)
        addChildViewController(mainViewController)
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChildViewController(mainViewController)
        mainViewController.didMoveToParentViewController(self)
        miniPlayerView.delegate = self
        mainViewContainer.addSubview(mainViewController.view)
        mainViewController.view.frame = mainViewContainer.bounds
        view.bringSubviewToFront(miniPlayerView)
        updateViews()
        player?.addObserver(miniPlayerObserver)
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
            let imageManager = SDWebImageManager()
            imageManager.downloadImageWithURL(
                track.thumbnailUrl,
                options: SDWebImageOptions.HighPriority,
               progress: {receivedSize, expectedSize in },
              completed: { (image, error, cacheType, finished, url) -> Void in
                let playingInfoCenter: AnyClass? = NSClassFromString("MPNowPlayingInfoCenter")
                if let center: AnyClass = playingInfoCenter {
                    let infoCenter = MPNowPlayingInfoCenter.defaultCenter()
                    let albumArt                     = MPMediaItemArtwork(image:image)
                    var info:[String:AnyObject]      = [:]
                    info[MPMediaItemPropertyTitle]   = track.title
                    info[MPMediaItemPropertyArtwork] = albumArt
                    infoCenter.nowPlayingInfo        = info
                }
            })
        } else {
            MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = nil
            miniPlayerView.titleLabel.text    = ""
            miniPlayerView.durationLabel.text = "00:00"
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
}
