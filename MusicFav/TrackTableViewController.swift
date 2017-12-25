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
import ReactiveSwift
import XCDYouTubeKit
import SDWebImage
import MusicFeeder
import PlayerKit

class TrackTableViewController: UITableViewController {
    var appDelegate: AppDelegate { return UIApplication.shared.delegate as! AppDelegate }
    var player:     QueuePlayer? { get { return appDelegate.player }}
    let tableCellReuseIdentifier = "trackTableViewCell"
    let cellHeight: CGFloat      = 80

    class TrackTableViewPlayerObserver: QueuePlayerObserver {
        let vc: TrackTableViewController
        init(viewController: TrackTableViewController) {
            vc = viewController
            super.init()
        }
        override func listen(_ event: Event) {
            switch event {
            case .statusChanged, .errorOccured, .playlistChanged: vc.updateSelection()
            case .trackSelected:             vc.updateSelection()
            case .trackUnselected:           vc.updateSelection()
            case .previousPlaylistRequested: break
            case .nextPlaylistRequested:     break
            case .timeUpdated:               break
            case .didPlayToEndTime:          break
            case .nextTrackAdded:            break
            }
        }
    }

    enum PlaylistType {
        case favorite
        case selected
        case playing
        case thirdParty
    }

    var playlistType: PlaylistType {
        if let p = appDelegate.selectedPlaylist {
            if p.id == playlist.id { return .selected }
        } else if let p = appDelegate.selectedPlaylist {
            if p.id == playlist.id { return .playing }
        }
        return .favorite
    }

    let playlistQueue = PlaylistQueue(playlists: [])
    var _playlist: MusicFeeder.Playlist!
    var playlistLoader: PlaylistRepository!
    var indicator:  UIActivityIndicatorView!
    var playerObserver:   TrackTableViewPlayerObserver!
    var playlistObserver: Disposable?
    var disposable: Disposable?

    var playlist: MusicFeeder.Playlist {
        return _playlist
    }

    var tracks: [MusicFeeder.Track] {
        return playlist.getTracks()
    }

    init(playlist: MusicFeeder.Playlist) {
        self._playlist  = playlist
        playlistLoader = PlaylistRepository(playlist: playlist)
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
        tableView?.register(nib, forCellReuseIdentifier:self.tableCellReuseIdentifier)
        updateNavbar()
        indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
        indicator.bounds = CGRect(x: 0,
                                  y: 0,
                              width: indicator.bounds.width,
                             height: indicator.bounds.height * 3)
        indicator.hidesWhenStopped = true
        indicator.stopAnimating()
        updateNavbar()
        observePlaylist()
        if playlistType == .favorite && tracks.count == 0 {
            showGuideMessage()
        }
        playlistQueue.enqueue(playlist)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        observePlayer()
        observePlaylist()
        fetchTracks()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if playerObserver != nil {
            appDelegate.player?.removeObserver(playerObserver)
        }
        playerObserver = nil
        playlistObserver?.dispose()
        playlistObserver = nil
        disposable?.dispose()
        disposable = nil
    }

    func updateNavbar() {
        let showFavListButton         = UIBarButtonItem(image: UIImage(named: "fav_list"),
                                                        style: UIBarButtonItemStyle.plain,
                                                       target: self,
                                                       action: #selector(TrackTableViewController.showFavoritePlaylist))
        let favPlaylistButton         = UIBarButtonItem(image: UIImage(named: "fav_playlist"),
                                                        style: UIBarButtonItemStyle.plain,
                                                       target: self,
                                                       action: #selector(TrackTableViewController.favPlaylist))
        let reorderButton             = UIBarButtonItem(image: UIImage(named: "edit"),
                                                        style: UIBarButtonItemStyle.plain,
                                                       target: self,
                                                       action: #selector(TrackTableViewController.reorder))
        navigationItem.rightBarButtonItems  = [showFavListButton]
        if playlistType != .playing {
            navigationItem.rightBarButtonItems?.append(favPlaylistButton)
        }
        if playlistType == .favorite {
            navigationItem.rightBarButtonItems?.append(reorderButton)
        }
    }

    func showGuideMessage() {
        let size =  tableView.bounds.size
        let backgroundView = UIView(frame: view.frame)
        let messageView = UILabel(frame: CGRect(x: size.width * 0.05, y: 0, width: size.width * 0.6, height: size.height))
        messageView.textAlignment      = NSTextAlignment.center
        messageView.numberOfLines      = 0
        messageView.clipsToBounds      = true
        tableView.separatorStyle       = UITableViewCellSeparatorStyle.none
        messageView.text = "Let's add your favorite tracks from ♥ button or swipe menu of a track".localize()
        tableView.backgroundView = backgroundView
        backgroundView.addSubview(messageView)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func observePlayer() {
        if playerObserver != nil {
            appDelegate.player?.removeObserver(playerObserver)
        }
        playerObserver = TrackTableViewPlayerObserver(viewController: self)
        appDelegate.player?.addObserver(playerObserver as QueuePlayerObserver)
        updateSelection()
    }

    func observePlaylist() {
        playlistObserver?.dispose()
        playlistObserver = Playlist.shared.signal.observeResult({ result in
            guard let event = result.value else { return }
            switch event {
            case .created(_): break
            case .removed(_): break
            case .updated(let playlist):
                if self.playlist == playlist {
                    self.tableView.reloadData()
                }
            case .tracksAdded(let playlist, let tracks):
                if self.playlist == playlist {
                    let offset = playlist.tracks.count-tracks.count
                    var indexes: [IndexPath] = []
                    for i in offset..<offset+tracks.count {
                        indexes.append(IndexPath(item: i, section: 0))
                    }
                    self.tableView.beginUpdates()
                    self.tableView.insertRows(at: indexes as [IndexPath], with: UITableViewRowAnimation.fade)
                    self.tableView.endUpdates()
                }
            case .trackRemoved(let playlist, _, let index):
                if self.playlist == playlist {
                    let indexPath = IndexPath(item: index, section: 0)
                    self.tableView.deleteRows(at: [indexPath], with: .fade)
                }
            case .trackUpdated(let playlist, _):
                if self.playlist == playlist {
                    self.tableView.reloadData()
                }
            case .sharedListUpdated: break
            }
            return
        })
    }

    func isPlaylistPlaying() -> Bool {
        if let p = appDelegate.player {
            if _playlist == p.currentPlaylist as? MusicFeeder.Playlist {
                return true
            }
        }
        return false
    }

    func isTrackPlaying(_ track: MusicFeeder.Track) -> Bool {
        if isPlaylistPlaying() {
            if let p = appDelegate.player, let t = p.currentTrack as? MusicFeeder.Track {
                return t == track
            }
        }
        return false
    }

    func updateSelection() {
        if !isPlaylistPlaying() {
            if let i = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at: i, animated: true)
            }
        } else {
            if let p = appDelegate.player {
                if _playlist != p.currentPlaylist as? MusicFeeder.Playlist {
                } else if let track = p.currentTrack as? MusicFeeder.Track {
                    if let index = _playlist.getTracks().index(of: track) {
                        tableView.selectRow(at: IndexPath(row: index, section: 0), animated: true, scrollPosition: UITableViewScrollPosition.none)
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

    @objc func showFavoritePlaylist() {
        let _ = navigationController?.popViewController(animated: true)
    }
    
    func showPlayingPlaylist() {
        Logger.sendUIActionEvent(self, action: "showPlayingPlaylist", label: "")
        appDelegate.miniPlayerViewController?.playlistTableViewController.showPlayingPlaylist(true)
    }

    func showSelectedPlaylist() {
        Logger.sendUIActionEvent(self, action: "showSelectedPlaylist", label: "")
        appDelegate.miniPlayerViewController?.playlistTableViewController.showSelectedPlaylist(true)
    }
    
    @objc func favPlaylist() {
        Logger.sendUIActionEvent(self, action: "favPlaylist", label: "")
        showSelectPlaylistViewController(playlist.getTracks())
    }

    @objc func reorder() {
        tableView.setEditing(!tableView.isEditing, animated: true)
    }

    func showSelectPlaylistViewController(_ tracks: [MusicFeeder.Track]) {
        let ptc = SelectPlaylistTableViewController()
        ptc.callback = {(playlist: MusicFeeder.Playlist?) in
            if let p = playlist {
                switch p.appendTracks(tracks) {
                case .success: break
                case .failure:
                    let message = "Failed to add tracks".localize()
                    let _ = UIAlertController.show(self, title: "MusicFav", message: message, handler: { action in })
                case .exceedLimit:
                    let message = String(format: "Track number of per playlist is limited to %d.".localize(), Playlist.trackNumberLimit) +
                            "Do you want to purchase \"Unlock Everything\".".localize()
                    let _ = UIAlertController.showPurchaseAlert(self, title: "MusicFav", message: message, handler: {action in })
                }
            }
            ptc.callback = nil
        }
        let nvc = UINavigationController(rootViewController: ptc)
        self.navigationController?.present(nvc, animated: true, completion: nil)
    }

    func fetchTracks() {
        fetchTrackDetails()
    }

    func fetchTrackDetails() {
        disposable = playlistLoader.fetchTracks().start()
    }

    // MARK: UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tracks.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.cellHeight
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.tableCellReuseIdentifier, for: indexPath) as! TrackTableViewCell
        let track = tracks[indexPath.item]
        switch track.status {
        case .loading:
            cell.trackNameLabel.text = "Loading...".localize()
        case .unavailable:
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
            cell.thumbImgView.sd_setImage(with: thumbnailUrl)
        } else {
            cell.thumbImgView.image = UIImage(named: "default_thumb")
        }
        if isTrackPlaying(track) {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: UITableViewScrollPosition.none)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let remove = UITableViewRowAction(style: .default, title: "Remove".localize()) {
            (action, indexPath) in
            Logger.sendUIActionEvent(self, action: "removeTrack", label: "\(indexPath.item)")
            self.playlist.removeTrackAtIndex(UInt(indexPath.item))
        }

        remove.backgroundColor = UIColor.red
        let copy = UITableViewRowAction(style: .default, title: "Fav　　".localize()) {
            (action, indexPath) in
            Logger.sendUIActionEvent(self, action: "FavTrackAtIndex", label: "\(indexPath.item)")
            let track = self.playlist.getTracks()[indexPath.item]
            self.showSelectPlaylistViewController([track])
        }
        copy.backgroundColor = UIColor.green
        if playlistType == .favorite {
            return [copy, remove]
        } else {
            return [copy]
        }
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let _ = playlist.moveTrackAtIndex(sourceIndexPath.item, toIndex: destinationIndexPath.item)
    }

    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return tableView.isEditing ? UITableViewCellEditingStyle.none : UITableViewCellEditingStyle.delete
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    }

    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let index = playlistQueue.indexOf(playlist)     else { return }
        guard let track = playlist.tracks.get(indexPath.item) else { return }
        if track.isValid {
            appDelegate.toggle(at: Index(track: indexPath.item, playlist: index), in: playlistQueue)
        } else {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
}
