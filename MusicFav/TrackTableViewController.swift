//
//  TrackTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 1/10/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import AVFoundation
import SwiftyJSON
import ReactiveCocoa
import XCDYouTubeKit
import SDWebImage


class TrackTableViewController: UITableViewController {
    let tableCellReuseIdentifier = "trackTableViewCell"
    let cellHeight: CGFloat      = 80
    
    var playlist: Playlist! = nil
    var playlistLoader: PlaylistLoader!
    var appDelegate: AppDelegate { get { return UIApplication.sharedApplication().delegate as! AppDelegate }}
    var isSelectedPlaylist: Bool {
        get {
            if playlist != nil && appDelegate.selectedPlaylist != nil {
                return playlist!.id == appDelegate.selectedPlaylist!.id
            }
            return false
        }
    }
    var isPlayingPlaying: Bool {
        get {
            if playlist != nil && appDelegate.selectedPlaylist != nil {
                return playlist!.id == appDelegate.selectedPlaylist!.id
            }
            return false
        }
    }

    init(playlist: Playlist) {
        self.playlist  = playlist
        playlistLoader = PlaylistLoader(playlist: playlist)
        super.init(nibName: nil, bundle: nil)
    }

    override init(style: UITableViewStyle) {
        super.init(style: style)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    deinit {}
    
    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        let nib = UINib(nibName: "TrackTableViewCell", bundle: nil)
        tableView?.registerNib(nib, forCellReuseIdentifier:self.tableCellReuseIdentifier)
        updateNavbar()
        fetchTrackDetails()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
    }

    func updateNavbar() {
        let showFavListButton         = UIBarButtonItem(image: UIImage(named: "fav_list"),
                                                        style: UIBarButtonItemStyle.Plain,
                                                       target: self,
                                                       action: "showFavoritePlaylist")
        let favPlaylistButton         = UIBarButtonItem(image: UIImage(named: "fav_playlist"),
                                                        style: UIBarButtonItemStyle.Plain,
                                                       target: self,
                                                       action: "favPlaylist")

        navigationItem.rightBarButtonItems  = [showFavListButton]
        if isSelectedPlaylist {
            navigationItem.rightBarButtonItems?.append(favPlaylistButton)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    func showFavoritePlaylist() {
        navigationController?.popToRootViewControllerAnimated(true)
    }
    
    func showPlayingPlaylist() {
        Logger.sendUIActionEvent(self, action: "showPlayingPlaylist", label: "")
        appDelegate.miniPlayerViewController?.playlistTableViewController.showPlayingPlaylist()
    }

    func showSelectedPlaylist() {
        Logger.sendUIActionEvent(self, action: "showSelectedPlaylist", label: "")
        appDelegate.miniPlayerViewController?.playlistTableViewController.showSelectedPlaylist()
    }
    
    func favPlaylist() {
        if let currentPlaylist = playlist {
            Logger.sendUIActionEvent(self, action: "favPlaylist", label: "")
            showSelectPlaylistViewController(currentPlaylist.tracks)
        }
    }

    func showSelectPlaylistViewController(tracks: [Track]) {
        let ptc = SelectPlaylistTableViewController()
        ptc.callback = {(playlist: Playlist?) in
            if let p = playlist {
                switch p.appendTracks(tracks) {
                case .Success:
                    if p == self.playlist {
                        var indexes: [NSIndexPath] = []
                        let offset = p.tracks.count-1
                        for i in offset..<tracks.count + offset {
                            indexes.append(NSIndexPath(forItem: i, inSection: 0))
                        }
                        self.tableView.insertRowsAtIndexPaths(indexes, withRowAnimation: UITableViewRowAnimation.Fade)
                    }
                case .Failure:
                    var message = "Failed to add tracks".localize()
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
        self.navigationController?.presentViewController(nvc, animated: true, completion: nil)
    }
    
    func fetchTrackDetails() {
        if playlist == nil {
            return
        }
        weak var _self = self
        playlistLoader.fetchTracks().start(
            next: { (index, track) in
                UIScheduler().schedule {
                    if let __self = _self {
                        __self.tableView?.reloadRowsAtIndexPaths([NSIndexPath(forItem: index, inSection: 0)],
                            withRowAnimation: UITableViewRowAnimation.None)
                        Playlist.notifyChange(.Updated(__self.playlist!))
                    }
                }
                return
            }, error: { error in
                self.tableView.reloadData()
            }, completed: {
                self.tableView.reloadData()
        })
    }

    // MARK: UITableViewDataSource
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let _playlist = playlist {
            return _playlist.tracks.count
        }
        return 0
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return self.cellHeight
    }
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(self.tableCellReuseIdentifier, forIndexPath: indexPath) as! TrackTableViewCell
        if let p = playlist {
            let track = p.tracks[indexPath.item]
            switch track.status {
            case .Loading:
                cell.trackNameLabel.text = "Loading...".localize()
            case .Unavailable:
                cell.trackNameLabel.text = "Unavailable".localize()
            default:
                if let title = track.title {
                    cell.trackNameLabel.text = title
                } else {
                    cell.trackNameLabel.text = ""
                }
            }
            let minutes = Int(floor(track.duration / 60))
            let seconds = Int(round(track.duration - Double(minutes) * 60))
            cell.durationLabel.text = String(format: "%.2d:%.2d", minutes, seconds)
            if let thumbnailUrl = track.thumbnailUrl {
                cell.thumbImgView.sd_setImageWithURL(thumbnailUrl)
            } else {
                cell.thumbImgView.image = UIImage(named: "default_thumb")
            }
            return cell
        } else {
            cell.trackNameLabel.text = ""
            cell.durationLabel.text  = ""
            cell.thumbImgView.image = UIImage(named: "default_thumb")
            return cell
        }
    }

    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        let remove = UITableViewRowAction(style: .Default, title: "Remove".localize()) {
            (action, indexPath) in
            Logger.sendUIActionEvent(self, action: "removeTrack", label: "\(indexPath.item)")
            self.playlist?.removeTrackAtIndex(UInt(indexPath.item))
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }

        remove.backgroundColor = UIColor.red
        let copy = UITableViewRowAction(style: .Default, title: "Fav　　".localize()) {
            (action, indexPath) in
            Logger.sendUIActionEvent(self, action: "FavTrackAtIndex", label: "\(indexPath.item)")
            let track = self.playlist!.tracks[indexPath.item]
            self.showSelectPlaylistViewController([track])
        }
        copy.backgroundColor = UIColor.green
        if isSelectedPlaylist {
            return [copy]
        } else {
            return [copy, remove]
        }
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    }

    
    // MARK: UITableViewDelegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let p = playlist {
            let track = p.tracks[indexPath.item]
            if track.streamUrl != nil {
                appDelegate.miniPlayerViewController?.select(indexPath.item, playlist: p, playlists: [p])
            } else {
                tableView.deselectRowAtIndexPath(indexPath, animated: true)
            }
        }
    }
}
