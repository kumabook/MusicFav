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
        presentViewController(nvc, animated: true, completion: nil)
    }
}
