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
    var mainViewController:       JASidePanelController!
    var timelineViewController:   TimelineTableViewController!
    var trackTableViewController: TrackTableViewController!
    var menuViewController:       MenuTableViewController!
    private var queuePlayer:      AVQueuePlayer?
    private var currentPlaylist:  Playlist = Playlist(url:"http://dummy")
    private var currentIndex:     Int = Int.min
    private var timeObserver:     AnyObject?
    
    @IBOutlet weak var mainViewContainer: UIView!
    var playButton:     UIButton!
    @IBOutlet weak var miniPlayerView: MiniPlayerView!

    override init() {
        super.init(nibName: "MiniPlayerViewController", bundle: NSBundle.mainBundle())
        mainViewController                      = JASidePanelController()
        timelineViewController                  = TimelineTableViewController(streamId: nil)
        trackTableViewController                = TrackTableViewController()
        menuViewController                      = MenuTableViewController()
        mainViewController.leftPanel            = UINavigationController(rootViewController:menuViewController)
        mainViewController.rightPanel           = UINavigationController(rootViewController:trackTableViewController)
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
        if currentIndex >= 0 && currentIndex < currentPlaylist.tracks.count {
            let track = currentPlaylist.tracks[currentIndex]
            self.miniPlayerView.titleLabel.text    = track.title
            self.miniPlayerView.durationLabel.text = "00:00"
            self.miniPlayerView.thumbImgView.sd_setImageWithURL(track.thumbnailUrl, completed: { (image, error, cacheType, url) -> Void in
                let playingInfoCenter: AnyClass? = NSClassFromString("MPNowPlayingInfoCenter")
                if let center: AnyClass = playingInfoCenter {
                    let albumArt = MPMediaItemArtwork(image:image)
                    let info = [MPMediaItemPropertyTitle: track.title,
                        MPMediaItemPropertyArtwork: albumArt]
                    MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = info
                }
            })
            let playingInfoCenter: AnyClass? = NSClassFromString("MPNowPlayingInfoCenter")
            if let center: AnyClass = playingInfoCenter {
                let info = [MPMediaItemPropertyTitle: track.title]
                MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = info
            }
        } else {
            self.miniPlayerView.titleLabel.text    = "..."
            self.miniPlayerView.durationLabel.text = "--:--"
            self.miniPlayerView.thumbImgView.sd_setImageWithURL(nil)
        }
    }
    
    func showOAuthViewController() {
        let oauthvc = FeedlyOAuthViewController(nibName:"FeedlyOAuthViewController", bundle:NSBundle.mainBundle())
        let vc = UINavigationController(rootViewController: oauthvc)
        self.presentViewController(vc, animated: true, {
        })
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
        if self.currentIndex == index && self.currentPlaylist.url == playlist.url {
            if let player = self.queuePlayer {
                if player.items().count > 0 {
                    player.play()
                    self.miniPlayerView.state = MiniPlayerView.State.Play
                }
            }
            return
        }
        self.currentPlaylist = playlist
        let count            = self.currentPlaylist.tracks.count
        self.currentIndex    = index % count
        if let player = self.queuePlayer {
            player.pause()
            player.removeTimeObserver(self.timeObserver)
            player.removeAllItems()
            player.removeObserver(self, forKeyPath: "status")
        }
        
        
        var _playerItems: [AVPlayerItem] = []
        for i in 0..<count {
            if let url = self.currentPlaylist.tracks[(index + i) % count].streamUrl {
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
        if currentIndex == Int.min || queuePlayer == nil {
            return
        }
        switch self.miniPlayerView.state {
        case .Pause:
            play(currentIndex, playlist: currentPlaylist)
        case .Play:
            queuePlayer!.pause()
            self.miniPlayerView.state = MiniPlayerView.State.Pause
        }
    }
    
    func previous() {
        if currentIndex == Int.min {
            return
        }
        switch self.miniPlayerView.state {
        case .Pause:
            currentIndex -= 1
            updateViews()
        case .Play:
            play(currentIndex-1, playlist: currentPlaylist)
        }
    }
    
    func next() {
        if currentIndex == Int.min {
            return
        }
        switch self.miniPlayerView.state {
        case .Pause:
            currentIndex += 1
            updateViews()
        case .Play:
            play(currentIndex+1, playlist: currentPlaylist)
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
        queuePlayer!.removeItem(queuePlayer!.currentItem)
        currentIndex = (currentIndex + 1) % currentPlaylist.tracks.count
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
