//
//  YouTubePlaylistItemTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/18/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import MusicFeeder
import ReactiveSwift

class YouTubePlaylistItemTableViewController: TrackTableViewController {
    var youtubePlaylist:       YouTubePlaylist!
    var youtubePlaylistLoader: YouTubePlaylistLoader!
    var observer:              Disposable?

    override var playlistType: PlaylistType {
        return .thirdParty
    }

    init(playlist: YouTubePlaylist, playlistLoader: YouTubePlaylistLoader) {
        youtubePlaylist       = playlist
        youtubePlaylistLoader = playlistLoader
        super.init(playlist: Playlist(id: youtubePlaylist.id, title: youtubePlaylist.title, tracks: []))
        updateTracks()
    }

    override init(style: UITableViewStyle) {
        super.init(style: style)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    deinit {}

    override func viewDidLoad() {
        observePlaylistLoader()
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        observePlaylistLoader()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func observePlaylistLoader() {
        observer?.dispose()
        observer = youtubePlaylistLoader.signal.observeResult({ result in
            guard let event = result.value else { return }
            switch event {
            case .startLoading:
                self.showIndicator()
            case .completeLoading:
                self.hideIndicator()
                self.updateTracks()
                self.playlistQueue.enqueue(self.playlist)
                self.tableView.reloadData()
                self.fetchTrackDetails()
            case .failToLoad:
                break
            }
        })
        tableView.reloadData()
    }

    func updateTracks() {
        let tracks = youtubePlaylistLoader.itemsOfPlaylist[youtubePlaylist]?.map { $0.track } ?? []
        _playlist = Playlist(id: youtubePlaylist.id, title: youtubePlaylist.title, tracks: tracks)
    }

    override func fetchTracks() {
        youtubePlaylistLoader.fetchPlaylistItems(youtubePlaylist)
    }

    override func fetchTrackDetails() {
        for track in tracks {
            track.fetchPropertiesFromProviderIfNeed().on(
                failed: { error in
                    self.tableView.reloadData()
            }, completed: {
                self.tableView.reloadData()
            }, value: { (track: Track?) in
                if let t = track {
                    if let index = self.tracks.index(of: t) {
                        self.tableView?.reloadRows(at: [IndexPath(item: index, section: 0)],
                                                   with: UITableViewRowAnimation.none)
                    }
                }
                return
            }).start()
        }
    }
}
