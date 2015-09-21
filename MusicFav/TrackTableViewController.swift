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
import WebImage
import MusicFeeder

class TrackTableViewController: UITableViewController {
    var appDelegate: AppDelegate { return UIApplication.sharedApplication().delegate as! AppDelegate }
    var player:     Player? { get { return appDelegate.player }}
    let tableCellReuseIdentifier = "trackTableViewCell"
    let cellHeight: CGFloat      = 80

    class TrackTableViewPlayerObserver: PlayerObserver {
        let vc: TrackTableViewController
        init(viewController: TrackTableViewController) {
            vc = viewController
            super.init()
        }
        override func timeUpdated()      {}
        override func didPlayToEndTime() {}
        override func statusChanged() {
            vc.updateSelection()
        }
        override func nextPlaylistRequested() {
        }
        override func previousPlaylistRequested() {
        }
        override func trackSelected(track: PlayerKitTrack, index: Int, playlist: PlayerKitPlaylist) {
            vc.updateSelection()
        }
        override func trackUnselected(track: PlayerKitTrack, index: Int, playlist: PlayerKitPlaylist) {
            vc.updateSelection()
        }
    }

    enum PlaylistType {
        case Favorite
        case Selected
        case Playing
        case ThirdParty
    }

    var playlistType: PlaylistType {
        if let p = appDelegate.selectedPlaylist {
            if p.id == playlist.id { return .Selected }
        } else if let p = appDelegate.selectedPlaylist {
            if p.id == playlist.id { return .Playing }
        }
        return .Favorite
    }

    var _playlist: Playlist!
    var playlistLoader: PlaylistLoader!
    var indicator:  UIActivityIndicatorView!
    var playerObserver: TrackTableViewPlayerObserver!

    var playlist: Playlist {
        return _playlist
    }

    var tracks: [Track] {
        return playlist.getTracks()
    }

    init(playlist: Playlist) {
        self._playlist  = playlist
        playlistLoader = PlaylistLoader(playlist: playlist)
        super.init(nibName: nil, bundle: nil)
    }

    override init(style: UITableViewStyle) {
        super.init(style: style)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    deinit {}
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "TrackTableViewCell", bundle: nil)
        tableView?.registerNib(nib, forCellReuseIdentifier:self.tableCellReuseIdentifier)
        updateNavbar()
        indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
        indicator.bounds = CGRect(x: 0,
                                  y: 0,
                              width: indicator.bounds.width,
                             height: indicator.bounds.height * 3)
        indicator.hidesWhenStopped = true
        indicator.stopAnimating()
        updateNavbar()

        fetchTracks()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        observePlayer()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        if playerObserver != nil {
            player?.removeObserver(playerObserver)
        }
        playerObserver = nil
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
        if playlistType != .Playing {
            navigationItem.rightBarButtonItems?.append(favPlaylistButton)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func observePlayer() {
        if playerObserver != nil {
            player?.removeObserver(playerObserver)
        }
        playerObserver = TrackTableViewPlayerObserver(viewController: self)
        player?.addObserver(playerObserver)
        updateSelection()
    }

    func isPlaylistPlaying() -> Bool {
        if let p = appDelegate.player {
            if _playlist == p.currentPlaylist as? Playlist {
                return true
            }
        }
        return false
    }

    func isTrackPlaying(track: Track) -> Bool {
        if isPlaylistPlaying() {
            if let p = appDelegate.player, t = p.currentTrack as? Track {
                return t == track
            }
        }
        return false
    }

    func updateSelection() {
        if !isPlaylistPlaying() {
            if let i = tableView.indexPathForSelectedRow {
                tableView.deselectRowAtIndexPath(i, animated: true)
            }
        } else {
            if let p = appDelegate.player {
                if _playlist != p.currentPlaylist as? Playlist {
                } else if let track = p.currentTrack as? Track {
                    if let index = _playlist.getTracks().indexOf(track) {
                        tableView.selectRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0), animated: true, scrollPosition: UITableViewScrollPosition.None)
                    }
                }
            }
        }
    }

    func showIndicator() {
        self.tableView.tableFooterView = indicator
        indicator?.startAnimating()
    }

    func hideIndicator() {
        indicator?.stopAnimating()
        self.tableView.tableFooterView = nil
    }

    func showFavoritePlaylist() {
        navigationController?.popViewControllerAnimated(true)
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
        Logger.sendUIActionEvent(self, action: "favPlaylist", label: "")
        showSelectPlaylistViewController(playlist.getTracks())
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
        self.navigationController?.presentViewController(nvc, animated: true, completion: nil)
    }

    func fetchTracks() {
        fetchTrackDetails()
    }

    func fetchTrackDetails() {
        weak var _self = self
        playlistLoader.fetchTracks().on(
            next: { (index, track) in
                UIScheduler().schedule {
                    if let __self = _self {
                        __self.tableView?.reloadRowsAtIndexPaths([NSIndexPath(forItem: index, inSection: 0)],
                            withRowAnimation: UITableViewRowAnimation.None)
                        Playlist.notifyChange(.Updated(__self.playlist))
                    }
                }
                return
            }, error: { error in
                self.tableView.reloadData()
            }, completed: {
                self.tableView.reloadData()
        }).start()
    }

    // MARK: UITableViewDataSource
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tracks.count
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return self.cellHeight
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(self.tableCellReuseIdentifier, forIndexPath: indexPath) as! TrackTableViewCell
        let track = tracks[indexPath.item]
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
        if isTrackPlaying(track) {
            tableView.selectRowAtIndexPath(indexPath, animated: false, scrollPosition: UITableViewScrollPosition.None)
        }
        return cell
    }

    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        let remove = UITableViewRowAction(style: .Default, title: "Remove".localize()) {
            (action, indexPath) in
            Logger.sendUIActionEvent(self, action: "removeTrack", label: "\(indexPath.item)")
            self.playlist.removeTrackAtIndex(UInt(indexPath.item))
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }

        remove.backgroundColor = UIColor.red
        let copy = UITableViewRowAction(style: .Default, title: "Fav　　".localize()) {
            (action, indexPath) in
            Logger.sendUIActionEvent(self, action: "FavTrackAtIndex", label: "\(indexPath.item)")
            let track = self.playlist.getTracks()[indexPath.item]
            self.showSelectPlaylistViewController([track])
        }
        copy.backgroundColor = UIColor.green
        if playlistType == .Favorite {
            return [copy, remove]
        } else {
            return [copy]
        }
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    }

    // MARK: UITableViewDelegate

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let track = playlist.tracks[indexPath.item]
        if track.streamUrl != nil {
            appDelegate.select(indexPath.item, playlist: playlist, playlists: [playlist])
        } else {
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
    }
}
