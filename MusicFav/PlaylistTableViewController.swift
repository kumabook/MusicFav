//
//  PlaylistTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2/7/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveSwift
import MusicFeeder
import SoundCloudKit
import YouTubeKit
import Breit

class PlaylistTableViewController: UITableViewController, UIAlertViewDelegate {
    let NEW_PLAYLIST_INDEX = -1
    var appDelegate: AppDelegate { get { return UIApplication.shared.delegate as! AppDelegate } }
    enum Section: Int {
        case playing     = 0
        case selected    = 1
        case youTube     = 2
        case soundCloud  = 3
        case spotify     = 4
        case appleMusic  = 5
        case favorites   = 6
        static let count = 7
        var title: String? {
            switch self {
            case .youTube:   return " "
            case .favorites: return " "
            default:         return nil
            }
        }
    }
    class PlaylistTableViewPlayerObserver: QueuePlayerObserver {
        let vc: PlaylistTableViewController
        init(playlistTableViewController: PlaylistTableViewController) {
            vc = playlistTableViewController
            super.init()
        }
        override func listen(_ event: Event) {
            switch event {
            case .timeUpdated: break
            case .didPlayToEndTime: break
            case .statusChanged:
                if let playlist = vc.appDelegate.playingPlaylist {
                    vc.updatePlaylist(playlist)
                }
            case .trackSelected:             update()
            case .trackUnselected:           update()
            case .previousPlaylistRequested: break
            case .nextPlaylistRequested:     break
            case .errorOccured:              break
            case .playlistChanged:           break
            case .nextTrackAdded:            break
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
        tableView?.register(nib, forCellReuseIdentifier:self.tableCellReuseIdentifier)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
        observePlaylists()
        observePlayer()
        updateNavbar()
    }

    override func viewWillDisappear(_ animated: Bool) {
        dispose()
    }

    func updateNavbar() {
        let newPlaylistButton = UIBarButtonItem(image: UIImage(named: "add_stream"),
                                                style: UIBarButtonItemStyle.plain,
                                               target: self,
                                               action: #selector(PlaylistTableViewController.newPlaylist))
        newPlaylistButton.accessibilityLabel = AccessibilityLabel.NewPlaylistButton.s
        let reorderButton     = UIBarButtonItem(image: UIImage(named: "reorder"),
                                                style: UIBarButtonItemStyle.plain,
                                               target: self,
                                               action: #selector(PlaylistTableViewController.reorder))
        navigationItem.rightBarButtonItems = [newPlaylistButton, reorderButton]
    }

    @objc func newPlaylist() {
        Logger.sendUIActionEvent(self, action: "newPlaylist", label: "")
        showTitleEditAlertViewAtIndex(NEW_PLAYLIST_INDEX)
    }

    @objc func reorder() {
        tableView.setEditing(!tableView.isEditing, animated: true)
    }

    func showPlaylist(_ playlist: MusicFeeder.Playlist, animated: Bool) -> TrackTableViewController {
        Logger.sendUIActionEvent(self, action: "showPlaylist", label: "")
        let ttc = TrackTableViewController(playlist: playlist)
        let _ = navigationController?.popToRootViewController(animated: animated)
        navigationController?.pushViewController(ttc, animated: animated)
        return ttc
    }

    func showPlayingPlaylist(_ animated: Bool) {
        Logger.sendUIActionEvent(self, action: "showPlayingPlaylist", label: "")
        if let playlist = appDelegate.playingPlaylist {
            let _ = showPlaylist(playlist, animated: animated)
        }
    }

    func showSelectedPlaylist(_ animated: Bool) {
        Logger.sendUIActionEvent(self, action: "showSelectedPlaylist", label: "")
        if let playlist = appDelegate.selectedPlaylist {
            let _ = showPlaylist(playlist, animated: animated)
        }
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

    func showSpotifyPlaylists() {
        Logger.sendUIActionEvent(self, action: "showSpotifyPlaylists", label: "")
        let vc = SpotifyPlaylistTableViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    func showAppleMusicPlaylists() {
        Logger.sendUIActionEvent(self, action: "showAppleMusicPlaylists", label: "")
        if #available(iOS 10.3, *) {
            let vc = AppleMusicPlaylistTableViewController()
            navigationController?.pushViewController(vc, animated: true)
        } else {
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
        playlistsObserver = Playlist.shared.signal.observeResult({ result in
            guard let event = result.value else { return }
            switch event {
            case .created(let playlist):
                self.createPlaylist(playlist)
            case .updated(let playlist):
                self.updatePlaylist(playlist)
            case .removed(let playlist):
                self.removePlaylist(playlist)
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
            return
        })
    }

    func createPlaylist(_ playlist: MusicFeeder.Playlist) {
        let section = Section.favorites.rawValue
        playlists = Playlist.shared.current
        guard let index = playlists.index(of: playlist) else {
            tableView.reloadData()
            return
        }
        let indexPath = IndexPath(item: index, section: section)
        tableView.insertRows(at: [indexPath], with: .fade)
    }

    func updatePlaylist(_ playlist: MusicFeeder.Playlist) {
        let section = Section.favorites.rawValue
        if playlist == appDelegate.playingPlaylist {
            let indexPath = IndexPath(item: 0, section: Section.playing.rawValue)
            tableView.reloadRows(at: [indexPath], with: .fade)
        } else if playlist == appDelegate.selectedPlaylist {
            let indexPath = IndexPath(item: 0, section: Section.selected.rawValue)
            tableView.reloadRows(at: [indexPath], with: .fade)
        }
        if let index = self.playlists.index(of: playlist) {
            let indexPath = IndexPath(item: index, section: section)
            playlists[index] = playlist
            tableView.reloadRows(at: [indexPath], with: .fade)
        }
    }

    func removePlaylist(_ playlist: MusicFeeder.Playlist) {
        let section = Section.favorites.rawValue
        if let index = playlists.index(of: playlist) {
            _ = playlists.remove(at: index)
            let indexPath = IndexPath(item: index, section: section)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    func showTitleEditAlertViewAtIndex(_ index: Int) {
        Logger.sendUIActionEvent(self, action: "showTitleEditAlertViewAtIndex", label: "")
        var title: String!
        if index >= 0 { title = "Edit playlist title".localize() }
        else          { title = "New playlist".localize() }
        let alert = UIAlertController(title: title, message: "", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Cancel".localize(), style: UIAlertActionStyle.cancel, handler: { action in
            self.tableView.reloadData()
            return
        }))
        alert.addAction(UIAlertAction(title: "OK".localize(), style: UIAlertActionStyle.default, handler: { action in
            guard let newTitle = alert.textFields?[0].text else { return }
            if index >= 0 {
                self.playlists[index].title = newTitle
                let _ = self.playlists[index].save()
            } else if index == self.NEW_PLAYLIST_INDEX {
                let playlist = Playlist(title: newTitle)
                switch playlist.create() {
                case .success: break
                case .failure:
                    let _ = UIAlertController.show(self, title: "MusicFav", message: "Failed to create playlist", handler: {action in })
                case .exceedLimit:
                    let message = String(format: "Playlist number is limited to %d.".localize(), Playlist.playlistNumberLimit) +
                        "Do you want to purchase \"Unlock Everything\".".localize()
                    let _ = UIAlertController.showPurchaseAlert(self, title: "MusicFav", message: message, handler: {action in })
                }
            }
            self.tableView.reloadData()
        }))
        alert.addTextField { textField in
            textField.accessibilityLabel = AccessibilityLabel.PlaylistName.s
            if index >= 0 { textField.text = self.playlists[index].title }
            else          { textField.text = "" }
        }
        present(alert, animated: true, completion: nil)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (Section(rawValue: section)!) {
        case .playing:    return 1
        case .selected:   return appDelegate.selectedPlaylist == nil ? 0 : 1
        case .youTube:    return 1
        case .soundCloud: return 1
        case .spotify:    return 1
        case .appleMusic: return 1
        case .favorites:  return playlists.count
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.cellHeight
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.tableCellReuseIdentifier, for: indexPath) as! PlaylistTableViewCell
        var playlist: MusicFeeder.Playlist?
        switch (Section(rawValue: indexPath.section)!) {
        case .playing:
            playlist = appDelegate.playingPlaylist
            if let p = playlist {
                cell.titleLabel.text = "Now playing".localize() + "(\(p.title))"
            } else {
                cell.titleLabel.text = "Not playing".localize()
            }
        case .selected:
            playlist = appDelegate.selectedPlaylist
            if let p = playlist {
                cell.titleLabel.text = "Selected".localize() + "(\(p.title))"
            } else {
                cell.titleLabel.text = "Not selected".localize()
            }
        case .favorites:
            playlist = playlists[indexPath.item]
            cell.titleLabel.text = playlists[indexPath.item].title
        case .youTube:
            cell.titleLabel.text = "YouTube Playlists"
            cell.thumbImageView.image = UIImage(named: "youtube")
            cell.trackNumLabel.text = ""
            return cell
        case .soundCloud:
            cell.titleLabel.text = "SoundCloud Playlists"
            cell.thumbImageView.image = UIImage(named: "soundcloud")
            cell.trackNumLabel.text = ""
            return cell
        case .spotify:
            cell.titleLabel.text = "Spotify Playlists"
            cell.thumbImageView.image = UIImage(named: "spotify")
            cell.trackNumLabel.text = ""
            return cell
        case .appleMusic:
            cell.titleLabel.text = "AppleMusic Playlists"
            cell.thumbImageView.image = UIImage(named: "apple_music_icon")
            cell.trackNumLabel.text = ""
            return cell
        }
        if let p = playlist, let thumbnailUrl = p.thumbnailUrl {
            cell.thumbImageView.sd_setImage(with: thumbnailUrl)
            cell.trackNumLabel.text = "\(p.tracks.count) tracks"
        } else {
            cell.thumbImageView.image = UIImage(named: "default_thumb")
            cell.trackNumLabel.text   = ""
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let edit = UITableViewRowAction(style: .default, title: "Edit title".localize()) {
            (action, indexPath) in
            switch (Section(rawValue: indexPath.section)!) {
            case .favorites:
                self.showTitleEditAlertViewAtIndex(indexPath.item)
            default:
                tableView.reloadRows(at: [indexPath], with: .right)
            }
        }
        edit.backgroundColor = UIColor.green
        let remove = UITableViewRowAction(style: .default, title: "Remove".localize()) {
            (action, indexPath) in
            switch (Section(rawValue: indexPath.section)!) {
            case .favorites:
                self.playlists[indexPath.item].remove()
            default:
                tableView.reloadRows(at: [indexPath], with: .right)
            }
        }
        remove.backgroundColor = UIColor.red
        return [edit, remove]
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let _ = Playlist.movePlaylistInSharedList(sourceIndexPath.item, toIndex: destinationIndexPath.item)
    }

    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return tableView.isEditing ? UITableViewCellEditingStyle.none : UITableViewCellEditingStyle.delete
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        switch (Section(rawValue: indexPath.section)!) {
        case .playing:    return false
        case .selected:   return false
        case .youTube:    return false
        case .soundCloud: return false
        case .spotify:    return false
        case .appleMusic: return false
        case .favorites:  return tableView.isEditing
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch (Section(rawValue: indexPath.section)!) {
        case .playing:
            showPlayingPlaylist(true)
        case .selected:
            showSelectedPlaylist(true)
        case .youTube:
            if YouTubeKit.APIClient.isLoggedIn {
                showYouTubePlaylists()
            } else {
                YouTubeKit.APIClient.authorize()
            }
        case .soundCloud:
            if SoundCloudKit.APIClient.shared.isLoggedIn && SoundCloudKit.APIClient.me != nil {
                showSoundCloudPlaylists()
            } else {
                SoundCloudKit.APIClient.authorize()
            }
        case .spotify:
            if SpotifyAPIClient.shared.isLoggedIn {
                showSpotifyPlaylists()
            } else if let vc = AppDelegate.shared.coverViewController {
                SpotifyAPIClient.shared.startAuthenticationFlow(viewController: vc)
            }
        case .appleMusic:
            if #available(iOS 9.3, *) {
                switch AppleMusicClient.shared.authroizationStatus {
                case .authorized:
                    showAppleMusicPlaylists()
                case .notDetermined:
                    break
                case .restricted:
                    break
                case .denied:
                    break
                }
            } else {
            }
        case .favorites:
            let _ = showPlaylist(playlists[indexPath.item], animated: true)
        }
    }
}
