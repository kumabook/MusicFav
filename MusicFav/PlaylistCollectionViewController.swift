//
//  PlaylistCollectionViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/28/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import AVFoundation
import SwiftyJSON
import ReactiveCocoa
import LlamaKit


let tableCellReuseIdentifier = "playlistTableViewCell"
/*
class PlaylistCollectionViewController: UICollectionViewController {
    var playlist: Playlist? = nil
    override init() {
        super.init(nibName: "PlaylistCollectionViewController", bundle: NSBundle.mainBundle())
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.clearsSelectionOnViewWillAppear = true
        let nib = UINib(nibName: "PlaylistCollectionViewCell", bundle: nil)
        self.collectionView!.registerNib(nib, forCellWithReuseIdentifier:tableCellReuseIdentifier)
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
                    self.collectionView?.reloadData()
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
                            self.collectionView!.reloadData()
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

    // MARK: UICollectionViewDataSource

    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        //#warning Incomplete method implementation -- Return the number of sections
        return 1
    }


    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let _playlist = playlist {
            return _playlist.tracks.count
        }
        return 0
    }

    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(tableCellReuseIdentifier, forIndexPath: indexPath) as PlaylistCollectionViewCell
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

    // MARK: UICollectionViewDelegate

    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        if let p = playlist {
            let track = p.tracks[indexPath.item]
            let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
            appDelegate.miniPlayerViewController?.play(indexPath.item, playlist: p)
        }
    }
    
    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(collectionView: UICollectionView, shouldHighlightItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(collectionView: UICollectionView, shouldShowMenuForItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }

    override func collectionView(collectionView: UICollectionView, canPerformAction action: Selector, forItemAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) -> Bool {
        return false
    }

    override func collectionView(collectionView: UICollectionView, performAction action: Selector, forItemAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) {
    
    }
    */
    
}*/
