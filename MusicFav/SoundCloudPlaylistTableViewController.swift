//
//  SoundCloudPlaylistTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/22/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import SoundCloudKit

class SoundCloudPlaylistTableViewController: UITableViewController {
    let tableCellReuseIdentifier = "playlistTableViewCell"
    let cellHeight: CGFloat      = 80

    var indicator:      UIActivityIndicatorView!

    var playlistLoader: SoundCloudPlaylistLoader!
    var observer:       Disposable?

    enum Section: Int {
        case Favorites   = 0
        case Playlists   = 1
        static var count = 2
    }

    init(user: SoundCloudKit.User) {
        playlistLoader = SoundCloudPlaylistLoader(user: user)
        super.init(nibName: nil, bundle: nil)
    }

    required init!(coder aDecoder: NSCoder!) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "PlaylistTableViewCell", bundle: nil)
        tableView?.registerNib(nib, forCellReuseIdentifier: tableCellReuseIdentifier)
        indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
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

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        observePlaylistLoader()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        observer?.dispose()
        observer = nil
    }

    func updateNavbar() {
        let showFavListButton = UIBarButtonItem(image: UIImage(named: "fav_list"),
                                                style: UIBarButtonItemStyle.Plain,
                                               target: self,
                                               action: "showFavoritePlaylist")
        navigationItem.rightBarButtonItems = [showFavListButton]
    }

    func showFavoritePlaylist() {
        navigationController?.popToRootViewControllerAnimated(true)
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
        observer = playlistLoader.signal.observe(next: { event in
            switch event {
            case .StartLoading:
                if self.playlistLoader.state == .Fetching {
                    self.showIndicator()
                }
            case .CompleteLoading:
                self.hideIndicator()
                self.tableView.reloadData()
            case .FailToLoad:
                break
            }
        })
        tableView.reloadData()
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return Section.count
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .Favorites: return 1
        case .Playlists: return playlistLoader.playlists.count
        }
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return self.cellHeight
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(self.tableCellReuseIdentifier, forIndexPath: indexPath) as! PlaylistTableViewCell
        switch Section(rawValue: indexPath.section)! {
        case .Favorites:
            cell.titleLabel.text    = "Favorites"
            cell.trackNumLabel.text = ""
            cell.thumbImageView.image = UIImage(named: "soundcloud")
        case .Playlists:
            var playlist = playlistLoader.playlists[indexPath.item]
            cell.titleLabel.text    = playlist.title
            cell.trackNumLabel.text = playlist.description
            if let url = playlist.artworkUrl?.toURL() {
                cell.thumbImageView.sd_setImageWithURL(url, placeholderImage: UIImage(named: "souncloud"))
            } else if let url = playlist.tracks.first?.thumbnailURLString.toURL() {
                cell.thumbImageView.sd_setImageWithURL(url, placeholderImage: UIImage(named: "soundcloud"))
            } else {
                cell.thumbImageView.image = UIImage(named: "soundcloud")
            }
        }
        return cell
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        observer?.dispose()
        observer = nil
        switch Section(rawValue: indexPath.section)! {
        case .Favorites:
            let vc = SoundCloudTrackTableViewController(tracks: playlistLoader.favorites)
            navigationController?.pushViewController(vc, animated: true)
        case .Playlists:
            let playlist = playlistLoader.playlists[indexPath.item]
            let vc = SoundCloudTrackTableViewController(tracks: playlist.tracks)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
