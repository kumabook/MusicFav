//
//  YouTubePlaylistTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/18/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa

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

    required init!(coder aDecoder: NSCoder!) {
        playlistLoader = YouTubePlaylistLoader()
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
        playlistLoader.fetchPlaylists()
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
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlistLoader.playlists.count
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return self.cellHeight
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(self.tableCellReuseIdentifier, forIndexPath: indexPath) as! PlaylistTableViewCell
        var playlist = playlistLoader.playlists[indexPath.item]
        cell.titleLabel.text    = playlist.title
        cell.trackNumLabel.text = playlist.description
        if let items = playlistLoader.itemsOfPlaylist[playlist] {
            if items.count > 0 { cell.trackNumLabel.text = "\(items.count) tracks" }
        }
        cell.thumbImageView.sd_setImageWithURL(playlist.thumbnailURL, placeholderImage: UIImage(named: "default_thumb"))
        return cell
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        observer?.dispose()
        observer = nil
        var playlist = playlistLoader.playlists[indexPath.item]
        let vc = YouTubePlaylistItemTableViewController(playlist: playlist, playlistLoader: playlistLoader)
        navigationController?.pushViewController(vc, animated: true)
    }
}
