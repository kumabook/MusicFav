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

class MiniPlayerViewController: PlayerKit.MiniPlayerViewController {
    var streamPageMenuController:    StreamPageMenuController!
    var playlistTableViewController: PlaylistTableViewController!
    var streamTreeViewController:    StreamTreeViewController!
    var currentPlaylist:             MusicFeeder.Playlist? { get { return player?.currentPlaylist as? MusicFeeder.Playlist }}
    var currentTrack:                MusicFeeder.Track?    { get { return player?.currentTrack as? MusicFeeder.Track }}
    var app:                         UIApplication { get { return UIApplication.sharedApplication() }}
    var appDelegate:                 AppDelegate   { get { return app.delegate as! AppDelegate }}

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
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func setStreamPageMenu(stream: Stream) {
        if let vc = mainViewController as? JASidePanelController {
            streamPageMenuController = StreamPageMenuController(stream: stream)
            vc.centerPanel = UINavigationController(rootViewController: streamPageMenuController)
            vc.showCenterPanelAnimated(true)
        }
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
