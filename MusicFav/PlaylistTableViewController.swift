//
//  PlaylistTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2/7/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import MusicFeeder
import SoundCloudKit

class PlaylistTableViewController: UITableViewController, UIAlertViewDelegate {
    let NEW_PLAYLIST_INDEX = -1
    var appDelegate: AppDelegate { get { return UIApplication.sharedApplication().delegate as! AppDelegate } }
    enum Section: Int {
        case Playing     = 0
        case Selected    = 1
        case YouTube     = 2
        case SoundCloud  = 3
        case Favorites   = 4
        static let count = 5
        var title: String? {
            switch self {
            case .YouTube:   return " "
            case .Favorites: return " "
            default:         return nil
            }
        }
    }
    class PlaylistTableViewPlayerObserver: PlayerObserver {
        let vc: PlaylistTableViewController
        init(playlistTableViewController: PlaylistTableViewController) {
            vc = playlistTableViewController
            super.init()
        }
        func notify(event: Event) {
            switch event {
            case .TimeUpdated: break
            case .DidPlayToEndTime: break
            case .StatusChanged:
                if let playlist = vc.appDelegate.playingPlaylist {
                    vc.updatePlaylist(playlist)
                }
            case .TrackSelected:             update()
            case .TrackUnselected:           update()
            case .PreviousPlaylistRequested: break
            case .NextPlaylistRequested:     break
            case .ErrorOccured:              break
            case .PlaylistChanged:           break
            case .NextTrackAdded:            break
            }
        }
        func update() {
            vc.updatePlaylist(vc.appDelegate.playingPlaylist!)
        }
    }
    let tableCellReuseIdentifier      = "playlistTableViewCell"
    let cellHeight:        CGFloat       = 80
    var playlists:         [MusicFeeder.Playlist]    = []
    var playerObserver:    PlaylistTableViewPlayerObserver?
    var playlistsObserver: Disposable?

    deinit {}

    func dispose() {
        if let observer = playerObserver {
            appDelegate.player?.removeObserver(observer)
        }
        playlistsObserver?.dispose()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        let nib = UINib(nibName: "PlaylistTableViewCell", bundle: nil)
        tableView?.registerNib(nib, forCellReuseIdentifier:self.tableCellReuseIdentifier)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
        observePlaylists()
        observePlayer()
        updateNavbar()
    }

    override func viewWillDisappear(animated: Bool) {
        dispose()
    }

    func updateNavbar() {
        let newPlaylistButton = UIBarButtonItem(image: UIImage(named: "add_stream"),
                                                style: UIBarButtonItemStyle.Plain,
                                               target: self,
                                               action: #selector(PlaylistTableViewController.newPlaylist))
        newPlaylistButton.accessibilityLabel = AccessibilityLabel.NewPlaylistButton.s
        navigationItem.rightBarButtonItems = [newPlaylistButton]
    }

    func newPlaylist() {
        Logger.sendUIActionEvent(self, action: "newPlaylist", label: "")
        showTitleEditAlertViewAtIndex(NEW_PLAYLIST_INDEX)
    }

    func showPlaylist(playlist: MusicFeeder.Playlist, animated: Bool) -> TrackTableViewController {
        Logger.sendUIActionEvent(self, action: "showPlaylist", label: "")
        let ttc = TrackTableViewController(playlist: playlist)
        navigationController?.popToRootViewControllerAnimated(animated)
        navigationController?.pushViewController(ttc, animated: animated)
        return ttc
    }

    func showPlayingPlaylist(animated: Bool) {
        Logger.sendUIActionEvent(self, action: "showPlayingPlaylist", label: "")
        if let playlist = appDelegate.playingPlaylist { showPlaylist(playlist, animated: animated) }
    }

    func showSelectedPlaylist(animated: Bool) {
        Logger.sendUIActionEvent(self, action: "showSelectedPlaylist", label: "")
        if let playlist = appDelegate.selectedPlaylist { showPlaylist(playlist, animated: animated) }
    }

    func showYouTubePlaylists() {
        Logger.sendUIActionEvent(self, action: "showYouTubePlaylists", label: "")
        let vc = YouTubePlaylistTableViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    func showSoundCloudPlaylists() {
        Logger.sendUIActionEvent(self, action: "showSoundCloudPlaylists", label: "")
        if let me = SoundCloudKit.APIClient.me {
            let vc = SoundCloudPlaylistTableViewController(user: me)
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func observePlayer() {
        playerObserver = PlaylistTableViewPlayerObserver(playlistTableViewController: self)
        appDelegate.player?.addObserver(playerObserver!)
    }

    func observePlaylists() {
        playlists = Playlist.shared.current
        tableView.reloadData()
        playlistsObserver = Playlist.shared.signal.observeNext({ event in
                switch event {
                case .Created(let playlist):
                    self.createPlaylist(playlist)
                case .Updated(let playlist):
                    self.updatePlaylist(playlist)
                case .Removed(let playlist):
                    self.removePlaylist(playlist)
                case .TracksAdded(let playlist, _):
                    self.updatePlaylist(playlist)
                case .TrackRemoved(let playlist, _, _):
                    self.updatePlaylist(playlist)
                case .TrackUpdated(let playlist, _):
                    self.updatePlaylist(playlist)
                }
                return
            })
    }

    func createPlaylist(playlist: MusicFeeder.Playlist) {
        let section = Section.Favorites.rawValue
        let indexPath = NSIndexPath(forItem: playlists.count, inSection: section)
        playlists.append(playlist)
        tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
    }

    func updatePlaylist(playlist: MusicFeeder.Playlist) {
        let section = Section.Favorites.rawValue
        if playlist == appDelegate.playingPlaylist {
            let indexPath = NSIndexPath(forItem: 0, inSection: Section.Playing.rawValue)
            tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if playlist == appDelegate.selectedPlaylist {
            let indexPath = NSIndexPath(forItem: 0, inSection: Section.Selected.rawValue)
            tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }
        if let index = self.playlists.indexOf(playlist) {
            let indexPath = NSIndexPath(forItem: index, inSection: section)
            playlists[index] = playlist
            tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }
    }

    func removePlaylist(playlist: MusicFeeder.Playlist) {
        let section = Section.Favorites.rawValue
        if let index = playlists.indexOf(playlist) {
            _ = playlists.removeAtIndex(index)
            let indexPath = NSIndexPath(forItem: index, inSection: section)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }
    }

    func showTitleEditAlertViewAtIndex(index: Int) {
        Logger.sendUIActionEvent(self, action: "showTitleEditAlertViewAtIndex", label: "")
        var title: String!
        if index >= 0 { title = "Edit playlist title".localize() }
        else          { title = "New playlist".localize() }
        let alertView = UIAlertView(title: title,
                                  message: "",
                                 delegate: self,
                        cancelButtonTitle: "Cancel".localize(),
                        otherButtonTitles: "OK".localize())
        alertView.alertViewStyle = UIAlertViewStyle.PlainTextInput
        alertView.tag = index
        alertView.textFieldAtIndex(0)?.accessibilityLabel = AccessibilityLabel.PlaylistName.s
        if index >= 0 { alertView.textFieldAtIndex(0)?.text = playlists[index].title }
        else          { alertView.textFieldAtIndex(0)?.text = "" }
        alertView.show()
    }

    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        if (buttonIndex == alertView.cancelButtonIndex) { tableView.reloadData(); return }
        let index = alertView.tag
        let newTitle = alertView.textFieldAtIndex(0)!.text!
        if index >= 0 {
            playlists[index].title = newTitle
            playlists[index].save()
        } else if index == NEW_PLAYLIST_INDEX {
            let playlist = Playlist(title: newTitle)
            switch playlist.create() {
            case .Success: break
            case .Failure:
                UIAlertController.show(self, title: "MusicFav", message: "Failed to create playlist", handler: {action in })
            case .ExceedLimit:
                let message = String(format: "Playlist number is limited to %d.".localize(), Playlist.playlistNumberLimit) +
                    "Do you want to purchase \"Unlock Everything\".".localize()
                UIAlertController.showPurchaseAlert(self, title: "MusicFav", message: message, handler: {action in })
            }
        }
        tableView.reloadData()
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return Section.count
    }

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (Section(rawValue: section)!) {
        case .Playing:    return 1
        case .Selected:   return appDelegate.selectedPlaylist == nil ? 0 : 1
        case .YouTube:    return 1
        case .SoundCloud: return 1
        case .Favorites:  return playlists.count
        }
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return self.cellHeight
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(self.tableCellReuseIdentifier, forIndexPath: indexPath) as! PlaylistTableViewCell
        var playlist: MusicFeeder.Playlist?
        switch (Section(rawValue: indexPath.section)!) {
        case .Playing:
            playlist = appDelegate.playingPlaylist
            if let p = playlist {
                cell.titleLabel.text = "Now playing".localize() + "(\(p.title))"
            } else {
                cell.titleLabel.text = "Not playing".localize()
            }
        case .Selected:
            playlist = appDelegate.selectedPlaylist
            if let p = playlist {
                cell.titleLabel.text = "Selected".localize() + "(\(p.title))"
            } else {
                cell.titleLabel.text = "Not selected".localize()
            }
        case .Favorites:
            playlist = playlists[indexPath.item]
            cell.titleLabel.text = playlists[indexPath.item].title
        case .YouTube:
            cell.titleLabel.text = "YouTube Playlists"
            cell.thumbImageView.image = UIImage(named: "youtube")
            cell.trackNumLabel.text = ""
            return cell
        case .SoundCloud:
            cell.titleLabel.text = "SoundCloud Playlists"
            cell.thumbImageView.image = UIImage(named: "soundcloud")
            cell.trackNumLabel.text = ""
            return cell
        }
        if let p = playlist, thumbnailUrl = p.thumbnailUrl {
            cell.thumbImageView.sd_setImageWithURL(thumbnailUrl)
            cell.trackNumLabel.text = "\(p.tracks.count) tracks"
        } else {
            cell.thumbImageView.image = UIImage(named: "default_thumb")
            cell.trackNumLabel.text   = ""
        }

        return cell
    }

    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        let edit = UITableViewRowAction(style: .Default, title: "Edit title".localize()) {
            (action, indexPath) in
            switch (Section(rawValue: indexPath.section)!) {
            case .Favorites:
                self.showTitleEditAlertViewAtIndex(indexPath.item)
            default:
                tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Right)
            }
        }
        edit.backgroundColor = UIColor.green
        let remove = UITableViewRowAction(style: .Default, title: "Remove".localize()) {
            (action, indexPath) in
            switch (Section(rawValue: indexPath.section)!) {
            case .Favorites:
                self.playlists[indexPath.item].remove()
            default:
                tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Right)
            }
        }
        remove.backgroundColor = UIColor.red
        return [edit, remove]
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        switch (Section(rawValue: indexPath.section)!) {
        case .Playing:
            showPlayingPlaylist(true)
        case .Selected:
            showSelectedPlaylist(true)
        case .YouTube:
            if YouTubeAPIClient.isLoggedIn {
                showYouTubePlaylists()
            } else {
                let vc = UINavigationController(rootViewController: YouTubeOAuthViewController())
                presentViewController(vc, animated: true, completion: {})
            }
        case .SoundCloud:
            if SoundCloudKit.APIClient.isLoggedIn {
                showSoundCloudPlaylists()
            } else {
                let vc = SoundCloudOAuthViewController()
                presentViewController(UINavigationController(rootViewController: vc), animated: true, completion: {})
            }
        case .Favorites:
            showPlaylist(playlists[indexPath.item], animated: true)
        }
    }
}
