//
//  MiniPlayerViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/28/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import AVFoundation

class MiniPlayerViewController:   UIViewController, MiniPlayerViewDelegate {
    var mainViewController:          JASidePanelController!
    var timelineViewController:      TimelineTableViewController!
    var playlistTableViewController: PlaylistTableViewController!
    var menuViewController:          MenuTableViewController!
    private var queuePlayer:         AVQueuePlayer?
    private var playlist:            Playlist?
    private var currentIndex:        Int = Int.min
    private var timeObserver:        AnyObject?
    var currentPlaylist: Playlist? {
        get {
            return playlist
        }
    }
    
    @IBOutlet weak var mainViewContainer: UIView!
    var playButton:     UIButton!
    @IBOutlet weak var miniPlayerView: MiniPlayerView!

    override init() {
        super.init(nibName: "MiniPlayerViewController", bundle: NSBundle.mainBundle())
        mainViewController                      = JASidePanelController()
        timelineViewController                  = TimelineTableViewController(streamId: nil)
        playlistTableViewController             = PlaylistTableViewController()
        menuViewController                      = MenuTableViewController()
        mainViewController.leftPanel            = UINavigationController(rootViewController:menuViewController)
        mainViewController.rightPanel           = UINavigationController(rootViewController:playlistTableViewController)
        mainViewController.centerPanel          = UINavigationController(rootViewController:timelineViewController)
        mainViewController.view.backgroundColor = UIColor.whiteColor()
        mainViewController.allowRightSwipe      = false
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
        println(miniPlayerView.frame.size)
        mainViewContainer.addSubview(mainViewController.view)
        mainViewController.view.frame = mainViewContainer.bounds
        view.bringSubviewToFront(miniPlayerView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.updateViews()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func updateViews() {
        if playlist == nil {
            return
        }
        let currentPlaylist = self.playlist!
        if currentIndex >= 0 && currentIndex < currentPlaylist.tracks.count {
            let track = currentPlaylist.tracks[currentIndex]
            let playingInfoCenter: AnyClass? = NSClassFromString("MPNowPlayingInfoCenter")
            if let center: AnyClass = playingInfoCenter {
                var info:[String:AnyObject]       = [:]
                info[MPMediaItemPropertyTitle] = track.title
                MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = info
            }
            self.miniPlayerView.titleLabel.text    = track.title
            self.miniPlayerView.durationLabel.text = "00:00"
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
            self.miniPlayerView.titleLabel.text    = "..."
            self.miniPlayerView.durationLabel.text = "--:--"
            self.miniPlayerView.thumbImgView.sd_setImageWithURL(nil)
        }
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
        println(self.currentIndex == index)
        if let _playlist = currentPlaylist {
            if self.currentIndex == index && _playlist.id == playlist.id {
                if let player = self.queuePlayer {
                    if player.items().count > 0 {
                        player.play()
                        self.miniPlayerView.state = MiniPlayerView.State.Play
                    }
                }
                return
            }
        }
        self.playlist = playlist
        let count            = playlist.tracks.count
        self.currentIndex    = index % count
        if let player = self.queuePlayer {
            player.pause()
            player.removeTimeObserver(self.timeObserver)
            player.removeAllItems()
            player.removeObserver(self, forKeyPath: "status")
        }
        
        
        var _playerItems: [AVPlayerItem] = []
        for i in 0..<count {
            if let url = playlist.tracks[(index + i) % count].streamUrl {
                _playerItems.append(AVPlayerItem(URL:url))
            }
        }
        let player = AVQueuePlayer(items: _playerItems)
        self.queuePlayer = player
        player.seekToTime(kCMTimeZero)
        var time = CMTimeMakeWithSeconds(1.0, 1)
        self.timeObserver = player.addPeriodicTimeObserverForInterval(time, queue:nil, usingBlock:self.updateTime)
        player.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.allZeros, context: nil)
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "playerDidPlayToEndTime",
            name: AVPlayerItemDidPlayToEndTimeNotification,
            object: nil)
        
        player.play()
        self.miniPlayerView.state = MiniPlayerView.State.Play
        self.updateViews()
    }
    
    func toggle() {
        if currentIndex == Int.min || queuePlayer == nil || playlist == nil {
            return
        }
        switch self.miniPlayerView.state {
        case .Pause:
            play(currentIndex, playlist: currentPlaylist!)
        case .Play:
            queuePlayer!.pause()
            self.miniPlayerView.state = MiniPlayerView.State.Pause
        }
    }
    
    func previous() {
        if currentIndex == Int.min || playlist == nil {
            return
        }
        switch self.miniPlayerView.state {
        case .Pause:
            currentIndex -= 1
            updateViews()
        case .Play:
            play(currentIndex-1, playlist: currentPlaylist!)
        }
    }
    
    func next() {
        if currentIndex == Int.min || playlist == nil {
            return
        }
        switch self.miniPlayerView.state {
        case .Pause:
            currentIndex += 1
            updateViews()
        case .Play:
            play(currentIndex+1, playlist: currentPlaylist!)
        }
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if queuePlayer == nil {
            return
        }
        
        if object as? NSObject == queuePlayer && keyPath  == "status" {
            switch queuePlayer!.status {
            case .ReadyToPlay:
                self.updateViews()
                break
            case .Failed:
                // notify error
                break
            case .Unknown:
                break
            }
        }
    }
    
    func playerDidPlayToEndTime() {
        println("playerDidPlayToEndTime")
        if playlist == nil {
            return
        }
        queuePlayer!.removeItem(queuePlayer!.currentItem)
        currentIndex = (currentIndex + 1) % currentPlaylist!.tracks.count
        updateViews()
    }
    
    func updateTime(time: CMTime) {
        if let player = queuePlayer {
            let currentSec  = CMTimeGetSeconds(time)
            let durationSec = CMTimeGetSeconds(player.currentItem.duration)
            self.miniPlayerView.durationLabel.text = NSString(format:"%02d:%02d", Int(floor(currentSec / 60)), Int(floor(currentSec % 60)))
        }
    }
    
    // MARK: - MiniPlayerViewDelegate -
    
    func miniPlayerViewPlayButtonTouched() {
        toggle()
    }
    
    func miniPlayerViewPreviousButtonTouched() {
        self.previous()
    }
    
    func miniPlayerViewNextButtonTouched() {
        self.next()
    }
    
    func miniPlayerViewThumbImgTouched() {
        if currentIndex == Int.min {
            return
        }
        showPlaylist()
    }
}