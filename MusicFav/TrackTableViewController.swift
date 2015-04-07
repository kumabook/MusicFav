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
import LlamaKit
import XCDYouTubeKit
import SDWebImage


class TrackTableViewController: UITableViewController {
    let tableCellReuseIdentifier = "trackTableViewCell"
    let cellHeight: CGFloat      = 80
    
    var playlist: Playlist! = nil
    var playlistLoader: PlaylistLoader!
    var appDelegate: AppDelegate { get { return UIApplication.sharedApplication().delegate as AppDelegate }}
    var isReadingPlaylist: Bool {
        get {
            if playlist != nil && appDelegate.readingPlaylist != nil {
                return playlist!.id == appDelegate.readingPlaylist!.id
            }
            return false
        }
    }
    var isPlayingPlaying: Bool {
        get {
            if playlist != nil && appDelegate.readingPlaylist != nil {
                return playlist!.id == appDelegate.readingPlaylist!.id
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        let nib = UINib(nibName: "TrackTableViewCell", bundle: nil)
        tableView?.registerNib(nib, forCellReuseIdentifier:self.tableCellReuseIdentifier)
        updateNavbar()
        fetchTrackDetails()
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
        if isReadingPlaylist {
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
        appDelegate.miniPlayerViewController?.playlistTableViewController.showPlayingPlaylist()
    }

    func showReadingPlaylist() {
        appDelegate.miniPlayerViewController?.playlistTableViewController.showReadingPlaylist()
    }
    
    func favPlaylist() {
        if let currentPlaylist = playlist {
            showSelectPlaylistViewController(currentPlaylist.tracks)
        }
    }

    func showSelectPlaylistViewController(tracks: [Track]) {
        let ptc = SelectPlaylistTableViewController()
        ptc.callback = {(playlist: Playlist?) in
            if let p = playlist {
                p.appendTracks(tracks)
                if p == self.playlist {
                    var indexes: [NSIndexPath] = []
                    let offset = p.tracks.count-1
                    for i in offset..<tracks.count + offset {
                        indexes.append(NSIndexPath(forItem: i, inSection: 0))
                    }
                    self.tableView.insertRowsAtIndexPaths(indexes, withRowAnimation: UITableViewRowAnimation.Fade)
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

        let loader = PlaylistLoader(playlist: playlist!)
        loader.fetchTracks().start(
            next: { (index, track) in
                self.tableView?.reloadRowsAtIndexPaths([NSIndexPath(forItem: index, inSection: 0)],
                                                        withRowAnimation: UITableViewRowAnimation.None)
                Playlist.notifyChange(.Updated(self.playlist!))
            }, error: { error in
            }, completed: {
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
        let cell = tableView.dequeueReusableCellWithIdentifier(self.tableCellReuseIdentifier, forIndexPath: indexPath) as TrackTableViewCell
        if let p = playlist {
            let track = p.tracks[indexPath.item]
            if let title = track.title { cell.trackNameLabel.text = title }
            else                       { cell.trackNameLabel.text = "Loading...".localize() }
            let minutes = Int(floor(track.duration / 60))
            let seconds = Int(round(track.duration - Double(minutes) * 60))
            cell.durationLabel.text = String(format: "%.2d:%.2d", minutes, seconds)
            cell.thumbImgView.sd_setImageWithURL(track.thumbnailUrl)
            return cell
        } else {
            cell.trackNameLabel.text = ""
            cell.durationLabel.text  = ""
            cell.thumbImgView.sd_setImageWithURL(nil)
            return cell
        }
    }

    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        let remove = UITableViewRowAction(style: .Default, title: "Remove".localize()) {
            (action, indexPath) in
            self.playlist?.removeTrackAtIndex(UInt(indexPath.item))
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }

        remove.backgroundColor = UIColor.red
        let copy = UITableViewRowAction(style: .Default, title: "Copy".localize()) {
            (action, indexPath) in
            let track = self.playlist!.tracks[indexPath.item]
            self.showSelectPlaylistViewController([track])
        }
        copy.backgroundColor = UIColor.green
        if isReadingPlaylist {
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
            if track.streamUrl != nil { appDelegate.miniPlayerViewController?.play(indexPath.item, playlist: p) }
            else                      { tableView.deselectRowAtIndexPath(indexPath, animated: true) }
        }
    }
}
