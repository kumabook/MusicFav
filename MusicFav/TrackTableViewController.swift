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
    
    var playlist: Playlist? = nil
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
            currentPlaylist.save()
            appDelegate.miniPlayerViewController?.playlistTableViewController.fetchPlaylists()
        }
    }

    func showSelectPlaylistViewController(track: Track) {
        let ptc = SelectPlaylistTableViewController()
        ptc.callback = {(playlist: Playlist?) in
            if let p = playlist {
                p.appendTrack(track)
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
        for (index, track) in enumerate(playlist!.tracks) {
            switch track.provider {
            case .Youtube:
                XCDYouTubeClient.defaultClient().getVideoWithIdentifier(track.serviceId, completionHandler: { (video, error) -> Void in
                    if let e = error {
                        println(e)
                        return
                    }
                    track.updatePropertiesWithYouTubeVideo(video)
                    self.tableView?.reloadData()
                })
            case .SoundCloud:
                SoundCloudAPIClient.sharedInstance.fetchTrack(track.serviceId)
                    .deliverOn(MainScheduler())
                    .start(
                        next: {audio in
                            track.updateProperties(audio)
                        },
                        error: {error in
                            println("--failure")
                        },
                        completed: {
                            self.tableView!.reloadData()
                    })
            }
        }
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
            else                       { cell.trackNameLabel.text = "Loading..." }
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
        let remove = UITableViewRowAction(style: .Default, title: "Remove") {
            (action, indexPath) in
            let track = self.playlist!.tracks.removeAtIndex(indexPath.item)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }
        remove.backgroundColor = ColorHelper.redColor
        let copy = UITableViewRowAction(style: .Default, title: "Copy") {
            (action, indexPath) in
            let track = self.playlist!.tracks[indexPath.item]
            self.showSelectPlaylistViewController(track)
        }
        copy.backgroundColor = ColorHelper.greenColor
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
