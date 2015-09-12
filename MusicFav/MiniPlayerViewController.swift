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
import WebImage
import FeedlyKit
import MusicFeeder
import PlayerKit
import MarqueeLabel

class MiniPlayerViewController: PlayerKit.MiniPlayerViewController {
    var playlistTableViewController: PlaylistTableViewController!
    var streamTreeViewController:    StreamTreeViewController!
    var currentPlaylist:             MusicFeeder.Playlist? { get { return player?.currentPlaylist as? MusicFeeder.Playlist }}
    var currentTrack:                MusicFeeder.Track?    { get { return player?.currentTrack as? MusicFeeder.Track }}
    var app:                         UIApplication { get { return UIApplication.sharedApplication() }}
    var appDelegate:                 AppDelegate   { get { return app.delegate as! AppDelegate }}

    var marqueeTitleLabel: MarqueeLabel!

    override init(player: Player<PlayerObserver>) {
        super.init(player: player)
        let vc                      = JASidePanelController()
        mainViewController          = vc
        playlistTableViewController = PlaylistTableViewController()
        streamTreeViewController    = StreamTreeViewController()
        vc.leftPanel                = UINavigationController(rootViewController:streamTreeViewController)
        vc.rightPanel               = UINavigationController(rootViewController:playlistTableViewController)
        vc.prepare()
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let vc = mainViewController as? JASidePanelController {
            vc.centerPanelContainer.backgroundColor = UIColor.whiteColor()
        }
        let w = view.frame.width
        let h = view.frame.height - miniPlayerHeight
        miniPlayerView = MiniPlayerView(frame: CGRectMake(0, h, w, miniPlayerHeight))
        miniPlayerView.delegate = self
        view.addSubview(miniPlayerView)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func updateViews() {
        super.updateViews()
        if let track = player?.currentTrack {
            marqueeTitleLabel?.text = track.title
        } else {
            marqueeTitleLabel?.text = ""
        }

    }

    func setCenterViewController(viewController: UIViewController) {
        if let vc = mainViewController as? JASidePanelController {
            vc.centerPanelContainer.backgroundColor = UIColor.transparent
            vc.centerPanel = UINavigationController(rootViewController: viewController)
            vc.showCenterPanelAnimated(true)
        }
    }

    func hasCenterViewController() -> Bool {
        if let vc = mainViewController as? JASidePanelController {
            return vc.centerPanel != nil
        }
        return false
    }

    func showMenu() {
        if let vc = mainViewController as? JASidePanelController {
            vc.showLeftPanelAnimated(true)
        }
    }

    func showPlaylist() {
        if let vc = mainViewController as? JASidePanelController {
            vc.showRightPanelAnimated(true)
        }
    }
}
