//
//  SelectPlaylistTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2/9/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

class SelectPlaylistTableViewController: UITableViewController {
    let tableCellReuseIdentifier = "selectPlaylistTableViewCell"
    let cellHeight: CGFloat      = 80
    var playlists: [Playlist] = []
    var callback: ((Playlist?) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        let nib = UINib(nibName: "SelectPlaylistTableViewCell", bundle: nil)
        tableView?.registerNib(nib, forCellReuseIdentifier:self.tableCellReuseIdentifier)
        fetchPlaylists()
    }

    override func viewWillAppear(animated: Bool) {
        updateNavbar()
    }

    func updateNavbar() {
        let closeButton = UIBarButtonItem(title: "Cancel",
                                          style: UIBarButtonItemStyle.Plain,
                                         target: self,
                                         action: "close")
        let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        navigationItem.leftBarButtonItems = [closeButton]
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func fetchPlaylists() {
        playlists = Playlist.findAll()
        tableView.reloadData()
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
        let cell = tableView.dequeueReusableCellWithIdentifier(self.tableCellReuseIdentifier, forIndexPath: indexPath) as SelectPlaylistTableViewCell
        let playlist = playlists[indexPath.item]
        cell.titleLabel.text    = playlist.title
        cell.trackNumLabel.text = "\(playlist.tracks.count) tracks"
        cell.thumbImageView.image = UIImage(named: "playlist_default_thumb")
        return cell
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        navigationController?.dismissViewControllerAnimated(true, completion: { () -> Void in
            if let callback = self.callback {
                callback(self.playlists[indexPath.item])
            }
        })
    }
}
