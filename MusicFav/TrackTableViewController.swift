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


class TrackTableViewController: UITableViewController {
    let tableCellReuseIdentifier = "trackTableViewCell"
    let cellHeight: CGFloat      = 80
    
    var playlist: Playlist? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.clearsSelectionOnViewWillAppear = true
        let nib = UINib(nibName: "TrackTableViewCell", bundle: nil)
        self.tableView?.registerNib(nib, forCellReuseIdentifier:self.tableCellReuseIdentifier)
        let showFavListButton          = UIBarButtonItem(image: UIImage(named: "fav_list"),
            style: UIBarButtonItemStyle.Plain,
            target: self,
            action: "showFavoritePlaylist")
        let showCurrentPlaylistButton  = UIBarButtonItem(image: UIImage(named: "current_playlist"),
            style: UIBarButtonItemStyle.Plain,
            target: self,
            action: "showCurrentPlaylist")
        let favPlaylistButton = UIBarButtonItem(image: UIImage(named: "fav_playlist"),
            style: UIBarButtonItemStyle.Plain,
            target: self,
            action: "favPlaylist")
        self.navigationItem.rightBarButtonItems  = [showCurrentPlaylistButton, favPlaylistButton, showFavListButton]
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    func showFavoritePlaylist() {
        //        self.navigationController?.pushViewController(TrackTableViewController(), animated: true)
    }
    
    func showCurrentPlaylist() {
        
    }
    
    func favPlaylist() {
        
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
    
    /*
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    }
    */
    
    // MARK: UITableViewDataSource
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        //#warning Incomplete method implementation -- Return the number of sections
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
            cell.trackNameLabel.text = track.title
            let minutes = Int(floor(track.duration / 60))
            let seconds = Int(round(track.duration - Double(minutes) * 60))
            cell.durationLabel.text = String(format: "%.2d:%.2d", minutes, seconds)
            cell.thumbImgView.sd_setImageWithURL(track.thumbnailUrl)
            return cell
        } else {
            cell.trackNameLabel.text = ""
            cell.durationLabel.text = ""
            cell.thumbImgView.sd_setImageWithURL(nil)
            return cell
        }
    }
    
    // MARK: UITableViewDelegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let p = playlist {
            let track = p.tracks[indexPath.item]
            let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
            appDelegate.miniPlayerViewController?.play(indexPath.item, playlist: p)
        }
    }
}
