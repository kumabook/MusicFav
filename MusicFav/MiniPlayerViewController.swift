//
//  MiniPlayerViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/28/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer
import SDWebImage
import FeedlyKit
import MusicFeeder
import PlayerKit
import MarqueeLabel
import DrawerController
import AMScrollingNavbar

class MiniPlayerViewController: PlayerKit.MiniPlayerViewController<PlayerKit.MiniPlayerView> {
    var playlistTableViewController: PlaylistTableViewController!
    var streamTreeViewController:    StreamTreeViewController!
    var drawlerController:           DrawerController!
    var currentPlaylist:             MusicFeeder.Playlist? { get { return player?.currentPlaylist as? MusicFeeder.Playlist }}
    var currentTrack:                MusicFeeder.Track?    { get { return player?.currentTrack as? MusicFeeder.Track }}
    var app:                         UIApplication { get { return UIApplication.shared }}
    var appDelegate:                 AppDelegate   { get { return app.delegate as! AppDelegate }}

    var marqueeTitleLabel: MarqueeLabel!

    override init(player: QueuePlayer) {
        super.init(player: player)
        playlistTableViewController = PlaylistTableViewController()
        streamTreeViewController    = StreamTreeViewController()
        drawlerController           = DrawerController(centerViewController: UIViewController(),
                                                   leftDrawerViewController: UINavigationController(rootViewController: streamTreeViewController),
                                                  rightDrawerViewController: UINavigationController(rootViewController: playlistTableViewController))
        drawlerController.centerViewController       = nil
        drawlerController.openDrawerGestureModeMask  = OpenDrawerGestureMode.all
        drawlerController.closeDrawerGestureModeMask = CloseDrawerGestureMode.panningCenterView
        drawlerController.shouldStretchDrawer        = false
        drawlerController.showsShadows               = true
        mainViewController                           = drawlerController
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            drawlerController.maximumLeftDrawerWidth  = view.frame.width * 0.4
            drawlerController.maximumRightDrawerWidth = view.frame.width * 0.4
        default:
            drawlerController.setMaximumLeftDrawerWidth(view.frame.width * 0.8, animated: true, completion: {_ in})
            drawlerController.setMaximumRightDrawerWidth(view.frame.width * 0.8, animated: true, completion: {_ in})
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
        if let vc = mainViewController as? DrawerController {
            let scrollingNavigationController = ScrollingNavigationController(rootViewController: viewController)
            vc.centerViewController = scrollingNavigationController
            vc.closeDrawer(animated: true, completion: nil)
        }
    }

    func hasCenterViewController() -> Bool {
        if let vc = mainViewController as? DrawerController {
            return vc.centerViewController != nil
        }
        return false
    }

    func showMenu() {
        if let vc = mainViewController as? DrawerController {
            vc.openDrawerSide(DrawerSide.left, animated: true, completion: nil)
        }
    }

    func showPlaylist() {
        if let vc = mainViewController as? DrawerController {
            vc.openDrawerSide(DrawerSide.right, animated: true, completion: nil)
        }
    }
}
