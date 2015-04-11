//
//  PlaylistTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2/7/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

class PlaylistTableViewController: UITableViewController, UIAlertViewDelegate {
    let NEW_PLAYLIST_INDEX = -1
    enum Section: Int {
        case Playing     = 0
        case Selected    = 1
        case Favorites   = 2
        static let count = 3
        var title: String? {
            get {
                switch self {
                case .Favorites:
                    return " "
                default:
                    return nil
                }
            }
        }
    }
    class PlaylistTableViewPlayerObserver: PlayerObserver {
        let vc: PlaylistTableViewController
        init(playlistTableViewController: PlaylistTableViewController) {
            vc = playlistTableViewController
            super.init()
        }
        override func timeUpdated()      {}
        override func didPlayToEndTime() {}
        override func statusChanged()    {}
        override func trackChanged()     { vc.updatePlaylist(vc.appDelegate.playingPlaylist!) }
        override func started()          {
        }
        override func ended()            {}
    }
    let tableCellReuseIdentifier      = "playlistTableViewCell"
    let cellHeight:     CGFloat       = 80
    var playlists:      [Playlist]    = []
    var playerObserver: PlaylistTableViewPlayerObserver?
    var appDelegate: AppDelegate { get { return UIApplication.sharedApplication().delegate as AppDelegate } }

    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        let nib = UINib(nibName: "PlaylistTableViewCell", bundle: nil)
        tableView?.registerNib(nib, forCellReuseIdentifier:self.tableCellReuseIdentifier)
    }

    override func viewWillAppear(animated: Bool) {
        observePlaylists()
        observePlayer()
        updateNavbar()
    }

    override func viewWillDisappear(animated: Bool) {
        if let observer = playerObserver {
            appDelegate.player?.removeObserver(observer)
        }
    }

    func updateNavbar() {
        let newPlaylistButton = UIBarButtonItem(image: UIImage(named: "add_stream"),
                                                style: UIBarButtonItemStyle.Plain,
                                               target: self,
                                               action: "newPlaylist")
        navigationItem.rightBarButtonItems = [newPlaylistButton]
    }

    func newPlaylist() {
        showTitleEditAlertViewAtIndex(NEW_PLAYLIST_INDEX)
    }

    func showPlaylist(playlist: Playlist) {
        let ttc = TrackTableViewController(playlist: playlist)
        navigationController?.popToRootViewControllerAnimated(true)
        navigationController?.pushViewController(ttc, animated: true)
    }

    func showPlayingPlaylist() {
        if let playlist = appDelegate.playingPlaylist { showPlaylist(playlist) }
    }

    func showSelectedPlaylist() {
        if let playlist = appDelegate.selectedPlaylist { showPlaylist(playlist) }
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
        Playlist.shared.signal.observe { event in
            let section = Section.Favorites.rawValue
            switch event {
            case .Created(let playlist):
                let indexPath = NSIndexPath(forItem: self.playlists.count, inSection: section)
                self.playlists.append(playlist)
                self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            case .Updated(let playlist):
                self.updatePlaylist(playlist)
            case .Removed(let playlist):
                if let index = find(self.playlists, playlist) {
                    let playlist = self.playlists.removeAtIndex(index)
                    let indexPath = NSIndexPath(forItem: index, inSection: section)
                    self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
                }
            case .TracksAdded(let playlist, let tracks):
                self.updatePlaylist(playlist)
            case .TrackRemoved(let playlist, let Track, let index):
                self.updatePlaylist(playlist)
            case .TrackUpdated(let playlist, let track):
                self.updatePlaylist(playlist)
            }
        }
    }

    func updatePlaylist(playlist: Playlist) {
        let section = Section.Favorites.rawValue
        if playlist == self.appDelegate.playingPlaylist {
            let indexPath = NSIndexPath(forItem: 0, inSection: Section.Playing.rawValue)
            self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if playlist == self.appDelegate.selectedPlaylist {
            let indexPath = NSIndexPath(forItem: 0, inSection: Section.Selected.rawValue)
            self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }
        if let index = find(self.playlists, playlist) {
            let indexPath = NSIndexPath(forItem: index, inSection: section)
            self.playlists[index] = playlist
            self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }
    }

    func showTitleEditAlertViewAtIndex(index: Int) {
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
        if index >= 0 { alertView.textFieldAtIndex(0)?.text = playlists[index].title }
        else          { alertView.textFieldAtIndex(0)?.text = "" }
        alertView.show()
    }

    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        if (buttonIndex == alertView.cancelButtonIndex) { tableView.reloadData(); return }
        let index = alertView.tag
        let newTitle = alertView.textFieldAtIndex(0)!.text
        if index >= 0 {
            playlists[index].title = newTitle
            playlists[index].save()
        } else if index == NEW_PLAYLIST_INDEX {
            let playlist = Playlist(title: newTitle)
            playlist.create()
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
        case .Playing:   return 1
        case .Selected:  return 1
        case .Favorites: return playlists.count
        }
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return self.cellHeight
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(self.tableCellReuseIdentifier, forIndexPath: indexPath) as PlaylistTableViewCell
        var playlist: Playlist?
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
        }
        if let p = playlist {
            cell.thumbImageView.sd_setImageWithURL(p.thumbnailUrl)
            cell.trackNumLabel.text = "\(p.tracks.count) tracks"
        } else {
            cell.thumbImageView.image = UIImage(named: "default_thumb")
            cell.trackNumLabel.text   = ""
        }

        return cell
    }

    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
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
            showPlayingPlaylist()
        case .Selected:
            showSelectedPlaylist()
        case .Favorites:
            showPlaylist(playlists[indexPath.item])
        }
    }
}
