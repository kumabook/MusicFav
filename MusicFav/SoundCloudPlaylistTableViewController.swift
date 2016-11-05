//
//  SoundCloudPlaylistTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/22/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveSwift
import SoundCloudKit

class SoundCloudPlaylistTableViewController: UITableViewController {
    let tableCellReuseIdentifier = "playlistTableViewCell"
    let cellHeight: CGFloat      = 80

    var indicator:      UIActivityIndicatorView!

    var playlistLoader: SoundCloudPlaylistLoader!
    var observer:       Disposable?

    enum Section: Int {
        case favorites   = 0
        case playlists   = 1
        static var count = 2
    }

    init(user: SoundCloudKit.User) {
        playlistLoader = SoundCloudPlaylistLoader(user: user)
        super.init(nibName: nil, bundle: nil)
    }

    required init!(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "PlaylistTableViewCell", bundle: nil)
        tableView?.register(nib, forCellReuseIdentifier: tableCellReuseIdentifier)
        indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
        indicator.bounds = CGRect(x: 0,
                                  y: 0,
                              width: indicator.bounds.width,
                             height: indicator.bounds.height * 3)
        indicator.hidesWhenStopped = true
        indicator.stopAnimating()
        updateNavbar()
        observePlaylistLoader()
        playlistLoader.fetchFavorites()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        observePlaylistLoader()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        observer?.dispose()
        observer = nil
    }

    func updateNavbar() {
        let showFavListButton = UIBarButtonItem(image: UIImage(named: "fav_list"),
                                                style: UIBarButtonItemStyle.plain,
                                               target: self,
                                               action: #selector(SoundCloudPlaylistTableViewController.showFavoritePlaylist))
        navigationItem.rightBarButtonItems = [showFavListButton]
    }

    func showFavoritePlaylist() {
        let _ = navigationController?.popToRootViewController(animated: true)
    }

    func showIndicator() {
        self.tableView.tableFooterView = indicator
        indicator?.startAnimating()
    }

    func hideIndicator() {
        indicator?.stopAnimating()
        self.tableView.tableFooterView = nil
    }

    func observePlaylistLoader() {
        observer?.dispose()
        observer = playlistLoader.signal.observeResult({ result in
            guard let event = result.value else { return }
            switch event {
            case .startLoading:
                if self.playlistLoader.state == .fetching {
                    self.showIndicator()
                }
            case .completeLoading:
                self.hideIndicator()
                self.tableView.reloadData()
            case .failToLoad:
                break
            }
        })
        tableView.reloadData()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .favorites: return 1
        case .playlists: return playlistLoader.playlists.count
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.cellHeight
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.tableCellReuseIdentifier, for: indexPath) as! PlaylistTableViewCell
        switch Section(rawValue: indexPath.section)! {
        case .favorites:
            cell.titleLabel.text    = "Favorites"
            cell.trackNumLabel.text = ""
            cell.thumbImageView.image = UIImage(named: "soundcloud")
        case .playlists:
            let playlist = playlistLoader.playlists[indexPath.item]
            cell.titleLabel.text    = playlist.title
            cell.trackNumLabel.text = playlist.description
            if let url = playlist.artworkUrl?.toURL() {
                cell.thumbImageView.sd_setImage(with: url, placeholderImage: UIImage(named: "souncloud"))
            } else if let url = playlist.tracks.first?.thumbnailURLString.toURL() {
                cell.thumbImageView.sd_setImage(with: url, placeholderImage: UIImage(named: "soundcloud"))
            } else {
                cell.thumbImageView.image = UIImage(named: "soundcloud")
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        observer?.dispose()
        observer = nil
        switch Section(rawValue: indexPath.section)! {
        case .favorites:
            let vc = SoundCloudTrackTableViewController(tracks: playlistLoader.favorites)
            navigationController?.pushViewController(vc, animated: true)
        case .playlists:
            let playlist = playlistLoader.playlists[indexPath.item]
            let vc = SoundCloudTrackTableViewController(tracks: playlist.tracks)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
