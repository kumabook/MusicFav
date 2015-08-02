//
//  PlaylistStreamViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/4/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import SwiftyJSON
import FeedlyKit
import MusicFeeder
import Box

class PlaylistStreamViewController: UITableViewController, PlaylistStreamTableViewCellDelegate {
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    var player:     Player<PlayerObserver>? { get { return appDelegate.player }}
    let cellHeight: CGFloat = 120
    let playlistStreamTableCellReuseIdentifier = "PlaylistStreamTableViewCell"

    var indicator:    UIActivityIndicatorView!
    var reloadButton: UIButton!
    var streamLoader: StreamLoader!
    var observer:     Disposable?
    var onpuRefreshControl:  OnpuRefreshControl!
    var playerObserver: PlaylistStreamPlayerObserver!

    class PlaylistStreamPlayerObserver: PlayerObserver {
        let vc: PlaylistStreamViewController
        init(playlistStreamViewController: PlaylistStreamViewController) {
            vc = playlistStreamViewController
            super.init()
        }
        override func timeUpdated()      {}
        override func didPlayToEndTime() {}
        override func statusChanged() {
            vc.updateSelection(UITableViewScrollPosition.Middle)
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

    init(streamLoader: StreamLoader) {
        self.streamLoader = streamLoader
        super.init(nibName: nil, bundle: nil)
    }

    override init(style: UITableViewStyle) {
        super.init(style: style)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
    }

    deinit {
        observer?.dispose()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.accessibilityIdentifier = AccessibilityLabel.PlaylistStreamTableView.s
        let nib = UINib(nibName: "PlaylistStreamTableViewCell", bundle: nil)
        tableView.registerNib(nib, forCellReuseIdentifier: playlistStreamTableCellReuseIdentifier)
        clearsSelectionOnViewWillAppear = true

        indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.White)
        indicator.bounds = CGRect(x: 0,
            y: 0,
            width: indicator.bounds.width,
            height: indicator.bounds.height * 3)
        indicator.hidesWhenStopped = true
        indicator.stopAnimating()

        reloadButton = UIButton()
        reloadButton.setImage(UIImage(named: "network_error"), forState: UIControlState.Normal)
        reloadButton.setTitleColor(UIColor.blackColor(), forState: UIControlState.Normal)
        reloadButton.addTarget(self, action:"fetchEntries", forControlEvents:UIControlEvents.TouchUpInside)
        reloadButton.setTitle("Sorry, network error occured.".localize(), forState:UIControlState.Normal)
        reloadButton.frame = CGRectMake(0, 0, tableView.frame.size.width, 44);

        let controlFrame   = CGRect(x: 0, y:0, width: view.frame.size.width, height: 80)
        onpuRefreshControl = OnpuRefreshControl(frame: controlFrame)
        onpuRefreshControl.addTarget(self, action: "fetchLatestEntries", forControlEvents:UIControlEvents.ValueChanged)
        tableView.addSubview(onpuRefreshControl)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
        let streamPageMenu: StreamPageMenuController? = appDelegate.miniPlayerViewController?.streamPageMenuController
        if let other = streamPageMenu?.entryStreamViewController {
            if other.tableView != nil {
                tableView.contentOffset = other.tableView.contentOffset
            }
        }
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        observeStreamLoader()
        if playerObserver != nil {
            player?.removeObserver(playerObserver)
        }
        playerObserver = PlaylistStreamPlayerObserver(playlistStreamViewController: self)
        player?.addObserver(playerObserver)
        updateSelection(UITableViewScrollPosition.None)
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        observer?.dispose()
        player?.removeObserver(playerObserver)
        playerObserver = nil
    }

    func indexPathOfPlaylist(playlist: Playlist) -> NSIndexPath? {
        for i in 0..<streamLoader.entries.count {
            if let p = streamLoader.playlistsOfEntry[streamLoader.entries[i]] {
                if p == playlist { return NSIndexPath(forRow: i, inSection: 0) }
            }
        }
        return nil
    }

    func updateSelection(scrollPosition: UITableViewScrollPosition) {
        if let p = appDelegate.player, pl = p.currentPlaylist as? Playlist {
            if let index = indexPathOfPlaylist(pl) {
                tableView.selectRowAtIndexPath(index, animated: true, scrollPosition: scrollPosition)
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
            let p = streamLoader.playlistsOfEntry[streamLoader.entries[indexPath.item]]
            p!.sink.put(.Next(Box(PlaylistEvent.ChangePlayState(index: index, playerState: playerState))))
        }
    }

    func observeStreamLoader() {
        observer?.dispose()
        observer = streamLoader.signal.observe(next: { event in
            switch event {
            case .StartLoadingLatest:
                self.onpuRefreshControl.beginRefreshing()
            case .CompleteLoadingLatest:
                let startTime = dispatch_time(DISPATCH_TIME_NOW, Int64(2.0 * Double(NSEC_PER_SEC)))
                dispatch_after(startTime, dispatch_get_main_queue()) {
                    self.tableView.reloadData()
                    self.onpuRefreshControl.endRefreshing()
                    self.updateSelection(UITableViewScrollPosition.None)
                }
            case .StartLoadingNext:
                self.showIndicator()
            case .CompleteLoadingNext:
                self.hideIndicator()
                self.tableView.reloadData()
                self.updateSelection(UITableViewScrollPosition.None)
            case .FailToLoadNext:
                self.showReloadButton()
            case .CompleteLoadingPlaylist(let playlist, let entry):
                if let i = find(self.streamLoader.entries, entry) {
                    if i < self.tableView.numberOfRowsInSection(0) {
                        let index = NSIndexPath(forItem: i, inSection: 0)
                        self.tableView.reloadRowsAtIndexPaths([index], withRowAnimation: UITableViewRowAnimation.None)
                    }
                }
                self.updateSelection(UITableViewScrollPosition.None)
            case .RemoveAt(let index):
                let indexPath = NSIndexPath(forItem: index, inSection: 0)
                self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            }
        })

        tableView?.reloadData()
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        appDelegate.miniPlayerViewController?.mainViewController.showCenterPanelAnimated(true)
    }

    func showPlaylist(playlist: Playlist?) {
        let vc = appDelegate.miniPlayerViewController
        if let _playlist = playlist {
            appDelegate.selectedPlaylist = _playlist
            appDelegate.miniPlayerViewController?.playlistTableViewController.updateNavbar()
            appDelegate.miniPlayerViewController?.playlistTableViewController.tableView.reloadData()
            vc?.mainViewController.showRightPanelAnimated(true, completion: {
                vc?.playlistTableViewController.showPlaylist(_playlist)
                return
            })
        }
    }

    func fetchLatestEntries() {
        streamLoader.fetchLatestEntries()
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
        for e in streamLoader.entries {
            if let playlist = streamLoader.playlistsOfEntry[e] {
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
        for e in streamLoader.entries {
            if let playlist = streamLoader.playlistsOfEntry[e] {
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
            appDelegate.miniPlayerViewController?.select(0, playlist: p, playlists: streamLoader.playlists)
        }
    }

    // MARK: - PlaylistStreamTableViewDelegate

    func trackSelectedAt(index: Int, track: Track, playlist: Playlist) {
        appDelegate.miniPlayerViewController?.select(index, playlist: playlist, playlists: streamLoader.playlists)
        tableView.reloadData()
    }

    func trackScrollViewMarginTapped(playlist: Playlist?) {
        if let _playlist = playlist {
            showPlaylist(playlist)
        }
    }

    // MARK: - Table view data source

    override func scrollViewDidScroll(scrollView: UIScrollView) {
        if tableView.contentOffset.y >= tableView.contentSize.height - tableView.bounds.size.height {
            streamLoader.fetchEntries()
        }
    }

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return streamLoader.entries.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let entry = streamLoader.entries[indexPath.row]
        let cell = tableView.dequeueReusableCellWithIdentifier(playlistStreamTableCellReuseIdentifier, forIndexPath:indexPath) as! PlaylistStreamTableViewCell
        cell.titleLabel.text = entry.title
        if let playlist = streamLoader.playlistsOfEntry[entry] {
            cell.delegate           = self
            cell.trackNumLabel.text = "\(playlist.tracks.count) tracks"
            cell.loadThumbnails(playlist)
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
            cell.observePlaylist(playlist)
        } else {
            cell.delegate           = nil
            cell.clearThumbnails()
            cell.trackNumLabel.text = "? tracks"
        }
        return cell
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let entry = streamLoader.entries[indexPath.row]
        if let playlist = streamLoader.playlistsOfEntry[entry] {
            Logger.sendUIActionEvent(self, action: "didSelectRowAtIndexPath", label: String(indexPath.row))
            showPlaylist(playlist)
        }
        updateSelection(UITableViewScrollPosition.None)
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return self.cellHeight
    }
}