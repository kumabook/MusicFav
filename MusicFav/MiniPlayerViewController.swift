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
import FeedlyKit
import MusicFeeder
import PlayerKit
import MarqueeLabel

class MiniPlayerViewController: PlayerKit.MiniPlayerViewController<PlayerKit.MiniPlayerView> {
    var playlistTableViewController: PlaylistTableViewController!
    var streamTreeViewController:    StreamTreeViewController!
    var currentPlaylist:             MusicFeeder.Playlist? { get { return player?.currentPlaylist as? MusicFeeder.Playlist }}
    var currentTrack:                MusicFeeder.Track?    { get { return player?.currentTrack as? MusicFeeder.Track }}
    var app:                         UIApplication { get { return UIApplication.shared }}
    var appDelegate:                 AppDelegate   { get { return app.delegate as! AppDelegate }}

    var marqueeTitleLabel: MarqueeLabel!

    override init(player: Player) {
        super.init(player: player)
        let vc                      = JASidePanelController()
        vc.shouldResizeRightPanel   = DeviceType.from(UIDevice.current) == .iPad
        mainViewController          = vc
        playlistTableViewController = PlaylistTableViewController()
        streamTreeViewController    = StreamTreeViewController()
        vc.leftPanel                = UINavigationController(rootViewController:streamTreeViewController)
        vc.rightPanel               = UINavigationController(rootViewController:playlistTableViewController)
        vc.prepare()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let vc = mainViewController as? JASidePanelController {
            vc.centerPanelContainer.backgroundColor = UIColor.white
        }
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

    func setCenterViewController(_ viewController: UIViewController) {
        if let vc = mainViewController as? JASidePanelController {
            vc.centerPanelContainer.backgroundColor = UIColor.transparent
            vc.centerPanel = UINavigationController(rootViewController: viewController)
            vc.showCenterPanel(animated: true)
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
            vc.showLeftPanel(animated: true)
        }
    }

    func showPlaylist() {
        if let vc = mainViewController as? JASidePanelController {
            vc.showRightPanel(animated: true)
        }
    }
}
