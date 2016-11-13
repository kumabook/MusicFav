//
//  TimelineTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/30/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveSwift
import SwiftyJSON
import FeedlyKit
import MusicFeeder
import DrawerController

class TimelineTableViewController: UITableViewController, TimelineTableViewCellDelegate {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var player:     Player? { return appDelegate.player }
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
        override func listen(_ event: Event) {
            switch event {
            case .statusChanged, .errorOccured, .playlistChanged:
                vc.updateSelection(UITableViewScrollPosition.none)
                vc.updateCurrentTrack()
            case .trackSelected(let track, let index, let playlist):
                vc.updateTrack(track, index: index, playlist: playlist, playerState: vc.player!.currentState)
                vc.tableView?.reloadData()
            case .trackUnselected(let track, let index, let playlist):
                vc.updateTrack(track, index: index, playlist: playlist, playerState: PlayerState.init)
                vc.tableView?.reloadData()
            case .previousPlaylistRequested: vc.playPlaylist(vc.previousPlaylist())
            case .nextPlaylistRequested:     vc.playPlaylist(vc.nextPlaylist())
            case .timeUpdated:               break
            case .didPlayToEndTime:          break
            case .nextTrackAdded:            break
            }
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
    func getPlaylistQueue() -> PlaylistQueue { return PlaylistQueue(playlists: []) }
    /** end */

    override func viewDidLoad() {
        super.viewDidLoad()
        observeApp()
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "playlist"),
                                                            style: UIBarButtonItemStyle.plain,
                                                           target: self,
                                                           action: #selector(TimelineTableViewController.showPlaylist as (TimelineTableViewController) -> () -> ()))
        navigationItem.title                            = timelineTitle.localize()
        navigationController?.toolbar.isTranslucent       = false
        navigationController?.navigationBar.isTranslucent = false
        let nib = UINib(nibName: "TimelineTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: reuseIdentifier)
        clearsSelectionOnViewWillAppear = true

        indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
        indicator.bounds = CGRect(x: 0,
                                  y: 0,
                              width: indicator.bounds.width,
                             height: indicator.bounds.height * 3)
        indicator.hidesWhenStopped = true
        indicator.stopAnimating()

        reloadButton = UIButton()
        reloadButton.setImage(UIImage(named: "network_error"), for: UIControlState())
        reloadButton.setTitleColor(UIColor.black, for: UIControlState())
        reloadButton.addTarget(self, action:#selector(TimelineTableViewController.fetchNext), for:UIControlEvents.touchUpInside)
        reloadButton.setTitle("Sorry, network error occured.".localize(), for:UIControlState.normal)
        reloadButton.frame = CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 44);

        let controlFrame   = CGRect(x: 0, y:0, width: view.frame.size.width, height: 80)
        onpuRefreshControl = OnpuRefreshControl(frame: controlFrame)
        onpuRefreshControl.addTarget(self, action: #selector(TimelineTableViewController.fetchLatest), for:UIControlEvents.valueChanged)
        tableView.addSubview(onpuRefreshControl)
        observer?.dispose()
        observer = observeTimelineLoader()
        fetchNext()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
        observer?.dispose()
        observer = observeTimelineLoader()
        reloadExpiredTracks()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if playerObserver != nil {
            appDelegate.player?.removeObserver(playerObserver)
        }
        playerObserver = TimelinePlayerObserver(viewController: self)
        appDelegate.player?.addObserver(playerObserver)
        updateSelection(UITableViewScrollPosition.none)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        observer?.dispose()
        appObserver?.dispose()
        if playerObserver != nil {
            appDelegate.player?.removeObserver(playerObserver)
        }
        playerObserver = nil
    }

    func reloadExpiredTracks() {
        for item in getItems() {
            item.playlist?.reloadExpiredTracks().on(value: {_ in self.tableView?.reloadData() }).start()
        }
        self.tableView?.reloadData()
    }

    func observeApp() {
        appObserver = appDelegate.signal?.observeResult({ result in
            guard let event = result.value else { return }
            if event == AppDelegate.Event.willEnterForeground {
                self.restorePlayerIcon()
                self.reloadExpiredTracks()
            }
        })
    }

    func restorePlayerIcon() {
        for visibleCell in tableView.visibleCells {
            if let cell = visibleCell as? TimelineTableViewCell, let indexPath = tableView.indexPath(for: visibleCell) {
                if let playlist = getItems()[indexPath.item].playlist {
                    updatePlayerIcon(cell, playlist: playlist)
                }
            }
        }
    }

    func indexPathOfPlaylist(_ playlist: Playlist) -> IndexPath? {
        let items = getItems()
        for i in 0..<items.count {
            if let p = items[i].playlist {
                if p == playlist { return IndexPath(row: i, section: 0) }
            }
        }
        return nil
    }

    func updateSelection(_ scrollPosition: UITableViewScrollPosition) {
        if let p = appDelegate.player, let pl = p.currentPlaylist as? Playlist {
            if let index = indexPathOfPlaylist(pl) {
                tableView.selectRow(at: index, animated: true, scrollPosition: scrollPosition)
                tableView.deselectRow(at: index, animated: false)
            }
        }
    }

    func updateCurrentTrack() {
        if let p = appDelegate.player, let pl = p.currentPlaylist, let t = p.currentTrack, let i = p.currentTrackIndex {
            updateTrack(t, index: i, playlist: pl, playerState: p.currentState)
        }
    }

    func updateTrack(_ track: PlayerKitTrack, index: Int, playlist: PlayerKitPlaylist, playerState: PlayerState) {
        if let p = playlist as? Playlist, let indexPath = indexPathOfPlaylist(p) {
            getItems()[indexPath.item].playlist?.observer.send(value: PlaylistEvent.changePlayState(index: index, playerState: playerState))
        }
    }

    func showMenu() {
        let vc = appDelegate.miniPlayerViewController
        vc?.showMenu()
    }

    func showPlaylist(_ playlist: Playlist?) {
        let vc = appDelegate.miniPlayerViewController
        if let playlist = playlist {
            appDelegate.selectedPlaylist = playlist
            vc?.playlistTableViewController.updateNavbar()
            vc?.playlistTableViewController.tableView.reloadData()
            appDelegate.mainViewController?.openDrawerSide(DrawerSide.right, animated: true, completion: { animated in
                let _ = vc?.playlistTableViewController.showPlaylist(playlist, animated: true)
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

    func playPlaylist(_ playlist: PlayerKitPlaylist?) {
        if let p = playlist as? Playlist {
            appDelegate.toggle(0, playlist: p, playlistQueue: getPlaylistQueue())
        }
    }

    func showPlaylistList() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainViewController?.openDrawerSide(DrawerSide.right, animated: true, completion: nil)
    }

    // MARK: - PlaylistStreamTableViewDelegate

    func trackSelected(_ sender: TimelineTableViewCell, index: Int, track: Track, playlist: Playlist) {
        appDelegate.toggle(index, playlist: playlist, playlistQueue: getPlaylistQueue())
        tableView.reloadData()
    }

    func trackScrollViewMarginTouched(_ sender: TimelineTableViewCell, playlist: Playlist?) {
        if let playlist = playlist, playlist.validTracksCount > 0 {
            showPlaylist(playlist)
        }
    }

    func playButtonTouched(_ sender: TimelineTableViewCell) {
        if let indexPath = tableView.indexPath(for: sender), let playlist = getItems()[indexPath.item].playlist {
            if let current = appDelegate.player?.currentPlaylist {
                if playlist.id == current.id {
                    appDelegate.toggle()
                    tableView.reloadData()
                    return
                }
            }
            appDelegate.toggle(0, playlist: playlist, playlistQueue: getPlaylistQueue())
            tableView.reloadRows(at: [indexPath], with: UITableViewRowAnimation.none)
            showPlaylist(playlist)
        }
    }

    func articleButtonTouched(_ sender: TimelineTableViewCell) {
        if let indexPath = tableView.indexPath(for: sender), let entry = getItems()[indexPath.item].entry {
            let vc = EntryWebViewController(entry: entry, playlist: getItems()[indexPath.item].playlist)
            appDelegate.selectedPlaylist = vc.playlist
            appDelegate.miniPlayerViewController?.playlistTableViewController.updateNavbar()
            appDelegate.miniPlayerViewController?.playlistTableViewController.tableView.reloadData()
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func updatePlayerIcon(_ cell: TimelineTableViewCell, playlist: Playlist) {
        if let p = self.player, let cp = p.currentPlaylist as? Playlist, let i = p.currentTrackIndex {
            if cp == playlist {
                cell.updatePlayerIcon(i, playerState: p.currentState)
                updateSelection(UITableViewScrollPosition.none)
            } else {
                cell.updatePlayerIcon(0, playerState: PlayerState.init)
            }
        } else {
            cell.updatePlayerIcon(0, playerState: PlayerState.init)
        }
    }

    // MARK: - Table view data source

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if tableView.contentOffset.y >= tableView.contentSize.height - tableView.bounds.size.height {
            fetchNext()
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return getItems().count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for:indexPath) as! TimelineTableViewCell
        let item = getItems()[indexPath.item]
        if let url = item.thumbnailURL {
            cell.backgroundImageView.sd_setImage(with: url)
            cell.backgroundImageView.backgroundColor = UIColor.clear
        } else {
            cell.backgroundImageView.image = nil
            cell.backgroundImageView.backgroundColor = UIColor.slateGray
        }
        cell.titleLabel.text       = item.title
        cell.descriptionLabel.text = item.description
        cell.dateLabel.text        = item.dateString
        cell.playButton.isHidden     = (item.playlist?.tracks.count)! <= 0
        cell.articleButton.isHidden  = item.entry == nil
        cell.trackNumLabel.text    = item.trackNumString
        cell.timelineDelegate      = self
        if let playlist = item.playlist {
            cell.loadThumbnails(playlist)
            updatePlayerIcon(cell, playlist: playlist)
            cell.observePlaylist(playlist)
        } else {
            cell.clearThumbnails()
            cell.updatePlayerIcon(0, playerState: PlayerState.init)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.cellHeight
    }
}
