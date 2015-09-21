//
//  SelectPlaylistTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2/9/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import MusicFeeder

class SelectPlaylistTableViewController: UITableViewController {
    let tableCellReuseIdentifier = "selectPlaylistTableViewCell"
    let cellHeight: CGFloat      = 80
    var playlists: [Playlist] = []
    var callback: ((Playlist?) -> Void)?

    var appDelegate: AppDelegate { get { return UIApplication.sharedApplication().delegate as! AppDelegate }}

    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        let nib = UINib(nibName: "SelectPlaylistTableViewCell", bundle: nil)
        tableView?.registerNib(nib, forCellReuseIdentifier:self.tableCellReuseIdentifier)
        observePlaylists()
    }

    override func viewWillAppear(animated: Bool) {
        Logger.sendScreenView(self)
        updateNavbar()
    }

    func updateNavbar() {
        let closeButton = UIBarButtonItem(title: "Cancel".localize(),
                                          style: UIBarButtonItemStyle.Plain,
                                         target: self,
                                         action: "close")
        let newPlaylistButton = UIBarButtonItem(image: UIImage(named: "add_stream"),
                                                style: UIBarButtonItemStyle.Plain,
                                               target: self,
                                               action: "newPlaylist")
        navigationItem.rightBarButtonItems = [newPlaylistButton]

        navigationItem.leftBarButtonItems = [closeButton]
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func observePlaylists() {
        playlists = Playlist.shared.current
        tableView.reloadData()
        Playlist.shared.signal.observeNext({ event in
                let section = 0
                switch event {
                case .Created(let playlist):
                    let indexPath = NSIndexPath(forItem: self.playlists.count, inSection: section)
                    self.playlists.append(playlist)
                    self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
                case .Updated(let playlist):
                    self.updatePlaylist(playlist)
                case .Removed(let playlist):
                    if let index = self.playlists.indexOf(playlist) {
                        self.playlists.removeAtIndex(index)
                        let indexPath = NSIndexPath(forItem: index, inSection: section)
                        self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
                    }
                case .TracksAdded(let playlist, _):
                    self.updatePlaylist(playlist)
                case .TrackRemoved(let playlist, _, _):
                    self.updatePlaylist(playlist)
                case .TrackUpdated(let playlist, _):
                    self.updatePlaylist(playlist)
                }
            })
    }

    func updatePlaylist(playlist: Playlist) {
        let section = 0
        if let index = self.playlists.indexOf(playlist) {
            let indexPath = NSIndexPath(forItem: index, inSection: section)
            self.playlists[index] = playlist
            self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }
    }

    func newPlaylist() {
        appDelegate.miniPlayerViewController?.playlistTableViewController.newPlaylist()
    }

    func editPlaylist(index: Int) {
        appDelegate.miniPlayerViewController?.playlistTableViewController.showTitleEditAlertViewAtIndex(index)
    }

    func close() {
        navigationController?.dismissViewControllerAnimated(true, completion: {
            if let callback = self.callback {
                callback(nil)
            }
        })
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlists.count
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return self.cellHeight
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(self.tableCellReuseIdentifier, forIndexPath: indexPath) as! SelectPlaylistTableViewCell
        let playlist = playlists[indexPath.item]
        cell.titleLabel.text    = playlist.title
        cell.trackNumLabel.text = "\(playlist.tracks.count) tracks"
        cell.thumbImageView.sd_setImageWithURL(playlist.thumbnailUrl)
        return cell
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        navigationController?.dismissViewControllerAnimated(true, completion: { () -> Void in
            if let callback = self.callback {
                callback(self.playlists[indexPath.item])
            }
        })
    }

    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        let edit = UITableViewRowAction(style: .Default, title: "Edit title".localize()) {
            (action, indexPath) in
            self.editPlaylist(indexPath.item)
        }
        edit.backgroundColor = UIColor.green
        let remove = UITableViewRowAction(style: .Default, title: "Remove".localize()) {
            (action, indexPath) in
            self.playlists[indexPath.item].remove()
        }
        remove.backgroundColor = UIColor.red
        return [edit, remove]
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
}
