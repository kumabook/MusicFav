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

    var appDelegate: AppDelegate { get { return UIApplication.shared.delegate as! AppDelegate }}

    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        let nib = UINib(nibName: "SelectPlaylistTableViewCell", bundle: nil)
        tableView?.register(nib, forCellReuseIdentifier:self.tableCellReuseIdentifier)
        observePlaylists()
    }

    override func viewWillAppear(_ animated: Bool) {
        Logger.sendScreenView(self)
        updateNavbar()
    }

    func updateNavbar() {
        let closeButton = UIBarButtonItem(title: "Cancel".localize(),
                                          style: UIBarButtonItemStyle.plain,
                                         target: self,
                                         action: #selector(SelectPlaylistTableViewController.close))
        let newPlaylistButton = UIBarButtonItem(image: UIImage(named: "add_stream"),
                                                style: UIBarButtonItemStyle.plain,
                                               target: self,
                                               action: #selector(SelectPlaylistTableViewController.newPlaylist))
        navigationItem.rightBarButtonItems = [newPlaylistButton]

        navigationItem.leftBarButtonItems = [closeButton]
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func observePlaylists() {
        playlists = Playlist.shared.current
        tableView.reloadData()
        Playlist.shared.signal.observeResult({ result in
            guard let event = result.value else { return }
            let section = 0
            switch event {
            case .created(let playlist):
                let indexPath = IndexPath(item: self.playlists.count, section: section)
                self.playlists.append(playlist)
                self.tableView.insertRows(at: [indexPath], with: .fade)
            case .updated(let playlist):
                self.updatePlaylist(playlist)
            case .removed(let playlist):
                if let index = self.playlists.index(of: playlist) {
                    self.playlists.remove(at: index)
                    let indexPath = IndexPath(item: index, section: section)
                    self.tableView.deleteRows(at: [indexPath], with: .fade)
                }
            case .tracksAdded(let playlist, _):
                self.updatePlaylist(playlist)
            case .trackRemoved(let playlist, _, _):
                self.updatePlaylist(playlist)
            case .trackUpdated(let playlist, _):
                self.updatePlaylist(playlist)
            case .sharedListUpdated:
                self.playlists = Playlist.shared.current
                self.tableView.reloadData()
            }
        })
    }

    func updatePlaylist(_ playlist: Playlist) {
        let section = 0
        if let index = self.playlists.index(of: playlist) {
            let indexPath = IndexPath(item: index, section: section)
            self.playlists[index] = playlist
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }
    }

    func newPlaylist() {
        appDelegate.miniPlayerViewController?.playlistTableViewController.newPlaylist()
    }

    func editPlaylist(_ index: Int) {
        appDelegate.miniPlayerViewController?.playlistTableViewController.showTitleEditAlertViewAtIndex(index)
    }

    func close() {
        navigationController?.dismiss(animated: true, completion: {
            if let callback = self.callback {
                callback(nil)
            }
        })
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlists.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.cellHeight
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.tableCellReuseIdentifier, for: indexPath) as! SelectPlaylistTableViewCell
        let playlist = playlists[indexPath.item]
        cell.titleLabel.text    = playlist.title
        cell.trackNumLabel.text = "\(playlist.tracks.count) tracks"
        cell.thumbImageView.sd_setImage(with: playlist.thumbnailUrl)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        navigationController?.dismiss(animated: true, completion: { () -> Void in
            if let callback = self.callback {
                callback(self.playlists[indexPath.item])
            }
        })
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let edit = UITableViewRowAction(style: .default, title: "Edit title".localize()) {
            (action, indexPath) in
            self.editPlaylist(indexPath.item)
        }
        edit.backgroundColor = UIColor.green
        let remove = UITableViewRowAction(style: .default, title: "Remove".localize()) {
            (action, indexPath) in
            self.playlists[indexPath.item].remove()
        }
        remove.backgroundColor = UIColor.red
        return [edit, remove]
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
}
