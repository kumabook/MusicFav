//
//  AppleMusicPlaylistTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2018/01/24.
//  Copyright © 2018 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import UIKit
import ReactiveSwift
import SoundCloudKit

@available(iOS 10.3, *)
class AppleMusicPlaylistTableViewController: UITableViewController {
    let tableCellReuseIdentifier = "playlistTableViewCell"
    let cellHeight: CGFloat      = 80

    var indicator:      UIActivityIndicatorView!

    var playlistRepository: AppleMusicPlaylistRepository!
    var observer:           Disposable?

    enum Section: Int {
        case playlists   = 0
        static var count = 1
    }

    init() {
        playlistRepository = AppleMusicPlaylistRepository()
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
        observePlaylistRepository()
        playlistRepository.fetchPlaylists()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        observePlaylistRepository()
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
                                                action: #selector(AppleMusicPlaylistTableViewController.showFavoritePlaylist))
        navigationItem.rightBarButtonItems = [showFavListButton]
    }

    @objc func showFavoritePlaylist() {
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

    func observePlaylistRepository() {
        observer?.dispose()
        observer = playlistRepository.signal.observeResult({ result in
            guard let event = result.value else { return }
            switch event {
            case .startLoading:
                if self.playlistRepository.state == .fetching {
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
        case .playlists: return playlistRepository.playlists.count
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.cellHeight
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.tableCellReuseIdentifier, for: indexPath) as! PlaylistTableViewCell
        switch Section(rawValue: indexPath.section)! {
        case .playlists:
            let playlist = playlistRepository.playlists[indexPath.item]
            cell.titleLabel.text    = playlist.name
            cell.trackNumLabel.text = playlist.descriptionText
            if let image = playlist.items.first?.artwork?.image(at: cell.thumbImageView.frame.size) {
                cell.thumbImageView.image = image
            } else {
                cell.thumbImageView.image = UIImage(named: "apple_music_icon")
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        observer?.dispose()
        observer = nil
        switch Section(rawValue: indexPath.section)! {
        case .playlists:
            let playlist = playlistRepository.playlists[indexPath.item]
            let vc = AppleMusicTrackTableViewController(playlist: playlist)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
