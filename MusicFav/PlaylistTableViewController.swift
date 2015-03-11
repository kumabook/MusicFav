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
        case Reading     = 1
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
    let tableCellReuseIdentifier = "playlistTableViewCell"
    let cellHeight: CGFloat      = 80
    var playlists: [Playlist]    = []
    var appDelegate: AppDelegate { get { return UIApplication.sharedApplication().delegate as AppDelegate } }

    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        let nib = UINib(nibName: "PlaylistTableViewCell", bundle: nil)
        tableView?.registerNib(nib, forCellReuseIdentifier:self.tableCellReuseIdentifier)
        observePlaylists()
    }

    override func viewWillAppear(animated: Bool) {
        updateNavbar()
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

    func showPlayingPlaylist() {
        if let playlist = appDelegate.playingPlaylist {
            let ptc = appDelegate.miniPlayerViewController!.playlistTableViewController
            let ttc = TrackTableViewController()
            ttc.playlist = playlist
            ptc.navigationController?.popToRootViewControllerAnimated(true)
            ptc.navigationController?.pushViewController(ttc, animated: true)
        }
    }

    func showReadingPlaylist() {
        if let playlist = appDelegate.readingPlaylist {
            let ptc = appDelegate.miniPlayerViewController!.playlistTableViewController
            let ttc = TrackTableViewController()
            ttc.playlist = playlist
            ptc.navigationController?.popToRootViewControllerAnimated(true)
            ptc.navigationController?.pushViewController(ttc, animated: true)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func observePlaylists() {
        playlists = Playlist.shared.current
        tableView.reloadData()
        Playlist.shared.signal.observe { event in
            let section = Section.Favorites.rawValue
            switch event.action {
            case .Create:
                let indexPath = NSIndexPath(forItem: self.playlists.count, inSection: section)
                self.playlists.append(event.value)
                self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            case .Update:
                if let index = find(self.playlists, event.value) {
                    let indexPath = NSIndexPath(forItem: index, inSection: section)
                    self.playlists[index] = event.value
                    self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
                }
            case .Remove:
                if let index = find(self.playlists, event.value) {
                    let playlist = self.playlists.removeAtIndex(index)
                    let indexPath = NSIndexPath(forItem: index, inSection: section)
                    self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
                }
            }
        }
    }

    func showTitleEditAlertViewAtIndex(index: Int) {
        var title: String!
        if index >= 0 { title = "Edit playlist title" }
        else          { title = "New playlist" }
        let alertView = UIAlertView(title: title,
                                  message: "",
                                 delegate: self,
                        cancelButtonTitle: "Cancel",
                        otherButtonTitles: "OK")
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
        case .Reading:   return 1
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
            if let p = appDelegate.playingPlaylist {
                cell.titleLabel.text = "Now playing(\(p.title))"
            } else {
                cell.titleLabel.text = "Not playing"
            }
        case .Reading:
            playlist = appDelegate.readingPlaylist
            if let p = appDelegate.readingPlaylist {
                cell.titleLabel.text = "Now reading(\(p.title))"
            } else {
                cell.titleLabel.text = "Not reading"
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
            cell.trackNumLabel.text    = ""
        }

        return cell
    }

    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        let edit = UITableViewRowAction(style: .Default, title: "Edit title") {
            (action, indexPath) in
            switch (Section(rawValue: indexPath.section)!) {
            case .Favorites:
                self.showTitleEditAlertViewAtIndex(indexPath.item)
            default:
                tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Right)
            }
        }
        edit.backgroundColor = ColorHelper.greenColor
        let remove = UITableViewRowAction(style: .Default, title: "Remove") {
            (action, indexPath) in
            switch (Section(rawValue: indexPath.section)!) {
            case .Favorites:
                self.playlists[indexPath.item].remove()
            default:
                tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Right)
            }
        }
        remove.backgroundColor = ColorHelper.redColor
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
        case .Reading:
            showReadingPlaylist()
        case .Favorites:
            let playlist = playlists[indexPath.item]
            let ttc = TrackTableViewController()
            ttc.playlist = playlist
            navigationController?.popViewControllerAnimated(true)
            navigationController?.pushViewController(ttc, animated: true)
        }
    }
}
