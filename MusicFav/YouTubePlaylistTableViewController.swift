//
//  YouTubePlaylistTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/18/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveSwift

class YouTubePlaylistTableViewController: UITableViewController {
    let tableCellReuseIdentifier = "playlistTableViewCell"
    let cellHeight: CGFloat      = 80

    var indicator:      UIActivityIndicatorView!

    var playlistLoader: YouTubePlaylistLoader
    var observer:       Disposable?

    init() {
        playlistLoader = YouTubePlaylistLoader()
        super.init(nibName: nil, bundle: nil)
    }

    required init!(coder aDecoder: NSCoder) {
        playlistLoader = YouTubePlaylistLoader()
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
        playlistLoader.fetchPlaylists()
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
                                               action: #selector(YouTubePlaylistTableViewController.showFavoritePlaylist))
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
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlistLoader.playlists.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.cellHeight
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.tableCellReuseIdentifier, for: indexPath) as! PlaylistTableViewCell
        let playlist = playlistLoader.playlists[indexPath.item]
        cell.titleLabel.text    = playlist.title
        cell.trackNumLabel.text = playlist.description
        if let items = playlistLoader.itemsOfPlaylist[playlist] {
            if items.count > 0 { cell.trackNumLabel.text = "\(items.count) tracks" }
        }
        cell.thumbImageView.sd_setImage(with: playlist.thumbnailURL, placeholderImage: UIImage(named: "default_thumb"))
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        observer?.dispose()
        observer = nil
        let playlist = playlistLoader.playlists[indexPath.item]
        let vc = YouTubePlaylistItemTableViewController(playlist: playlist, playlistLoader: playlistLoader)
        navigationController?.pushViewController(vc, animated: true)
    }
}
