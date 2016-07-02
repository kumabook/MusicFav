//
//  PlayerViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/12/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import PlayerKit
import MusicFeeder

class PlayerViewController: PlayerKit.SimplePlayerViewController {
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    let buttonSize:    CGFloat = 40.0
    let buttonPadding: CGFloat = 20.0
    var likeButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func initializeSubviews() {
        super.initializeSubviews()
        likeButton = UIButton(type: UIButtonType.System)
        likeButton.tintColor = UIColor.whiteColor()
        likeButton.setImage(UIImage(named: "like"), forState: UIControlState())
        likeButton.addTarget(self, action: #selector(PlayerViewController.likeButtonTapped), forControlEvents: UIControlEvents.TouchUpInside)
        view.addSubview(likeButton)
    }

    override func updateConstraints() {
        super.updateConstraints()
        likeButton.snp_makeConstraints { make in
            make.left.equalTo(self.view.snp_left).offset(self.buttonPadding)
            make.bottom.equalTo(self.view.snp_bottom).offset(-self.buttonPadding*1.5)
            make.width.equalTo(self.buttonSize)
            make.height.equalTo(self.buttonSize)
        }
    }

    func likeButtonTapped() {
        let app = UIApplication.sharedApplication().delegate as! AppDelegate
        if let track = app.player?.currentTrack as? MusicFeeder.Track{
            showSelectPlaylistViewController([track])
        }
    }

    func showSelectPlaylistViewController(tracks: [MusicFeeder.Track]) {
        let ptc = SelectPlaylistTableViewController()
        ptc.callback = {(playlist: MusicFeeder.Playlist?) in
            if let p = playlist {
                switch p.appendTracks(tracks) {
                case .Success:
                    break
                case .Failure:
                    let message = "Failed to add tracks".localize()
                    UIAlertController.show(self, title: "MusicFav", message: message, handler: { action in })
                case .ExceedLimit:
                    let message = String(format: "Track number of per playlist is limited to %d.".localize(), Playlist.trackNumberLimit) +
                        "Do you want to purchase \"Unlock Everything\".".localize()
                    UIAlertController.showPurchaseAlert(self, title: "MusicFav", message: message, handler: {action in })
                }
            }
            ptc.callback = nil
        }
        let nvc = UINavigationController(rootViewController: ptc)
        appDelegate.window?.rootViewController?.presentViewController(nvc, animated: true, completion: nil)
    }
}
