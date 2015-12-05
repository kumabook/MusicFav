//
//  TimelineTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/30/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import SwiftyJSON
import FeedlyKit
import MusicFeeder

class TimelineTableViewController: UITableViewController, TimelineTableViewCellDelegate {
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    var player:     Player? { get { return appDelegate.player }}
    let cellHeight: CGFloat = 190
    let reuseIdentifier = "TimelineTableViewCell"

    var indicator:    UIActivityIndicatorView!
    var reloadButton: UIButton!
    var observer:     Disposable?
    var appObserver:  Disposable?
    var onpuRefreshControl:  OnpuRefreshControl!
    var playerObserver: TimelinePlayerObserver!

    class TimelinePlayerObserver: PlayerObserver {
        let vc: TimelineTableViewController
        init(viewController: TimelineTableViewController) {
            vc = viewController
            super.init()
        }
        override func timeUpdated()      {}
        override func didPlayToEndTime() {}
        override func statusChanged() {
            vc.updateSelection(UITableViewScrollPosition.None)
            vc.updateCurrentTrack()
        }
        override func nextPlaylistRequested() {
            vc.playPlaylist(vc.nextPlaylist())
        }
        override func previousPlaylistRequested() {
            vc.playPlaylist(vc.previousPlaylist())
        }
        override func trackSelected(track: PlayerKitTrack, index: Int, playlist: PlayerKitPlaylist) {
            vc.updateTrack(track, index: index, playlist: playlist, playerState: vc.player!.currentState)
            vc.tableView?.reloadData()
        }
        override func trackUnselected(track: PlayerKitTrack, index: Int, playlist: PlayerKitPlaylist) {
            vc.updateTrack(track, index: index, playlist: playlist, playerState: PlayerState.Init)
            vc.tableView?.reloadData()
        }
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    override init(style: UITableViewStyle) {
        super.init(style: style)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
    }

    deinit {
        observer?.dispose()
        appObserver?.dispose()
    }

    /** should be override in subclass */
    var timelineTitle: String { return "" }
    func getItems() -> [TimelineItem] { return [] }
    func fetchLatest() {}
    func fetchNext() {}
    func observeTimelineLoader() -> Disposable? { return nil }
    /** end */

    func getPlaylists() -> [Playlist] {
        return getItems().flatMap { $0.playlist.map { [$0]} ?? [] }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        observeApp()
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "playlist"),
                                                            style: UIBarButtonItemStyle.Plain,
                                                           target: self,
                                                           action: "showPlaylist")
        navigationItem.title                            = timelineTitle.localize()
        navigationController?.toolbar.translucent       = false
        navigationController?.navigationBar.translucent = false
        let nib = UINib(nibName: "TimelineTableViewCell", bundle: nil)
        tableView.registerNib(nib, forCellReuseIdentifier: reuseIdentifier)
        clearsSelectionOnViewWillAppear = true

        indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
        indicator.bounds = CGRect(x: 0,
                                  y: 0,
                              width: indicator.bounds.width,
                             height: indicator.bounds.height * 3)
        indicator.hidesWhenStopped = true
        indicator.stopAnimating()

        reloadButton = UIButton()
        reloadButton.setImage(UIImage(named: "network_error"), forState: UIControlState.Normal)
        reloadButton.setTitleColor(UIColor.blackColor(), forState: UIControlState.Normal)
        reloadButton.addTarget(self, action:"fetchNext", forControlEvents:UIControlEvents.TouchUpInside)
        reloadButton.setTitle("Sorry, network error occured.".localize(), forState:UIControlState.Normal)
        reloadButton.frame = CGRectMake(0, 0, tableView.frame.size.width, 44);

        let controlFrame   = CGRect(x: 0, y:0, width: view.frame.size.width, height: 80)
        onpuRefreshControl = OnpuRefreshControl(frame: controlFrame)
        onpuRefreshControl.addTarget(self, action: "fetchLatest", forControlEvents:UIControlEvents.ValueChanged)
        tableView.addSubview(onpuRefreshControl)
        observer?.dispose()
        observer = observeTimelineLoader()
        fetchNext()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
        observer?.dispose()
        observer = observeTimelineLoader()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if playerObserver != nil {
            player?.removeObserver(playerObserver)
        }
        playerObserver = TimelinePlayerObserver(viewController: self)
        player?.addObserver(playerObserver)
        updateSelection(UITableViewScrollPosition.None)
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        observer?.dispose()
        appObserver?.dispose()
        if playerObserver != nil {
            player?.removeObserver(playerObserver)
        }
        playerObserver = nil
    }

    func observeApp() {
        appObserver = appDelegate.signal?.observeNext({ event in
            if event == AppDelegate.Event.WillEnterForeground {
                self.restorePlayerIcon()
            }
        })
    }

    func restorePlayerIcon() {
        for visibleCell in tableView.visibleCells {
            if let cell = visibleCell as? TimelineTableViewCell, indexPath = tableView.indexPathForCell(visibleCell) {
                if let playlist = getItems()[indexPath.item].playlist {
                    updatePlayerIcon(cell, playlist: playlist)
                }
            }
        }
    }

    func indexPathOfPlaylist(playlist: Playlist) -> NSIndexPath? {
        let items = getItems()
        for i in 0..<items.count {
            if let p = items[i].playlist {
                if p == playlist { return NSIndexPath(forRow: i, inSection: 0) }
            }
        }
        return nil
    }

    func updateSelection(scrollPosition: UITableViewScrollPosition) {
        if let p = appDelegate.player, pl = p.currentPlaylist as? Playlist {
            if let index = indexPathOfPlaylist(pl) {
                tableView.selectRowAtIndexPath(index, animated: true, scrollPosition: scrollPosition)
                tableView.deselectRowAtIndexPath(index, animated: false)
            }
        }
    }

    func updateCurrentTrack() {
        if let p = appDelegate.player, pl = p.currentPlaylist, t = p.currentTrack, i = p.currentTrackIndex {
            updateTrack(t, index: i, playlist: pl, playerState: p.currentState)
        }
    }

    func updateTrack(track: PlayerKitTrack, index: Int, playlist: PlayerKitPlaylist, playerState: PlayerState) {
        if let p = playlist as? Playlist, indexPath = indexPathOfPlaylist(p) {
            getItems()[indexPath.item].playlist?.observer.sendNext(PlaylistEvent.ChangePlayState(index: index, playerState: playerState))
        }
    }

    func showPlaylist(playlist: Playlist?) {
        let vc = appDelegate.miniPlayerViewController
        if let _playlist = playlist {
            appDelegate.selectedPlaylist = _playlist
            vc?.playlistTableViewController.updateNavbar()
            vc?.playlistTableViewController.tableView.reloadData()
            appDelegate.mainViewController?.showRightPanelAnimated(true, completion: {
                vc?.playlistTableViewController.showPlaylist(_playlist, animated: true)
                return
            })
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

    func showReloadButton() {
        self.tableView.tableFooterView = reloadButton
    }

    func hideReloadButton() {
        self.tableView.tableFooterView = nil
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func previousPlaylist() -> Playlist? {
        var prev: Playlist?
        for e in getItems() {
            if let playlist = e.playlist {
                if let p = player?.currentPlaylist as? Playlist {
                    if p == playlist {
                        return prev
                    }
                }
                if playlist.validTracksCount > 0 {
                    prev = playlist
                }
            }
        }
        return nil
    }

    func nextPlaylist() -> Playlist? {
        var find = false
        for e in getItems() {
            if let playlist = e.playlist {
                if find && playlist.validTracksCount > 0 {
                    return playlist
                }
                if let p = player?.currentPlaylist as? Playlist {
                    if p == playlist {
                        find = true
                    }
                }
            }
        }
        return nil
    }

    func playPlaylist(playlist: PlayerKitPlaylist?) {
        if let p = playlist as? Playlist {
            appDelegate.select(0, playlist: p, playlists: getPlaylists())
        }
    }

    func showPlaylist() {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        appDelegate.mainViewController?.showRightPanelAnimated(true)
    }

    // MARK: - PlaylistStreamTableViewDelegate

    func trackSelected(sender: TimelineTableViewCell, index: Int, track: Track, playlist: Playlist) {
        appDelegate.select(index, playlist: playlist, playlists: getPlaylists())
        tableView.reloadData()
    }

    func trackScrollViewMarginTouched(sender: TimelineTableViewCell, playlist: Playlist?) {
        if let _playlist = playlist {
            showPlaylist(_playlist)
        }
    }

    func playButtonTouched(sender: TimelineTableViewCell) {
        if let indexPath = tableView.indexPathForCell(sender), playlist = getItems()[indexPath.item].playlist {
            if let current = appDelegate.player?.currentPlaylist {
                if playlist.id == current.id {
                    appDelegate.toggle()
                    tableView.reloadData()
                    return
                }
            }
            appDelegate.select(0, playlist: playlist, playlists: getPlaylists())
            tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.None)
            showPlaylist(playlist)
        }
    }

    func articleButtonTouched(sender: TimelineTableViewCell) {
        if let indexPath = tableView.indexPathForCell(sender), entry = getItems()[indexPath.item].entry {
            let vc = EntryWebViewController(entry: entry, playlist: getItems()[indexPath.item].playlist)
            appDelegate.selectedPlaylist = vc.playlist
            appDelegate.miniPlayerViewController?.playlistTableViewController.updateNavbar()
            appDelegate.miniPlayerViewController?.playlistTableViewController.tableView.reloadData()
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func updatePlayerIcon(cell: TimelineTableViewCell, playlist: Playlist) {
        if let p = self.player, cp = p.currentPlaylist as? Playlist, i = p.currentTrackIndex {
            if cp == playlist {
                cell.updatePlayerIcon(i, playerState: p.currentState)
                updateSelection(UITableViewScrollPosition.None)
            } else {
                cell.updatePlayerIcon(0, playerState: PlayerState.Init)
            }
        } else {
            cell.updatePlayerIcon(0, playerState: PlayerState.Init)
        }
    }

    // MARK: - Table view data source

    override func scrollViewDidScroll(scrollView: UIScrollView) {
        if tableView.contentOffset.y >= tableView.contentSize.height - tableView.bounds.size.height {
            fetchNext()
        }
    }

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return getItems().count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath:indexPath) as! TimelineTableViewCell
        let item = getItems()[indexPath.item]
        if let url = item.thumbnailURL {
            cell.backgroundImageView.sd_setImageWithURL(url)
            cell.backgroundImageView.backgroundColor = UIColor.clearColor()
        } else {
            cell.backgroundImageView.image = nil
            cell.backgroundImageView.backgroundColor = UIColor.slateGray
        }
        cell.titleLabel.text       = item.title
        cell.descriptionLabel.text = item.description
        cell.dateLabel.text        = item.dateString
        cell.playButton.hidden     = item.playlist?.tracks.count <= 0
        cell.articleButton.hidden  = item.entry == nil
        cell.trackNumLabel.text    = item.trackNumString
        cell.timelineDelegate      = self
        if let playlist = item.playlist {
            cell.loadThumbnails(playlist)
            updatePlayerIcon(cell, playlist: playlist)
            cell.observePlaylist(playlist)
        } else {
            cell.clearThumbnails()
        }
        return cell
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return self.cellHeight
    }
}
