//
//  YouTubePlaylistItemTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/18/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import MusicFeeder
import ReactiveCocoa

class YouTubePlaylistItemTableViewController: TrackTableViewController {
    var youtubePlaylist:       YouTubePlaylist!
    var youtubePlaylistLoader: YouTubePlaylistLoader!
    var observer:              Disposable?

    override var playlistType: PlaylistType {
        return .ThirdParty
    }

    override var playlist: Playlist {
        return Playlist(title: youtubePlaylist.title,
                       tracks: tracks)
    }

    override var tracks: [Track] {
        return self.youtubePlaylistLoader.itemsOfPlaylist[youtubePlaylist]?.map { $0.track } ?? []
    }

    init(playlist: YouTubePlaylist, playlistLoader: YouTubePlaylistLoader) {
        self.youtubePlaylist       = playlist
        self.youtubePlaylistLoader = playlistLoader
        super.init(playlist: Playlist(title: youtubePlaylist.title,
                                     tracks: []))
    }

    override init(style: UITableViewStyle) {
        super.init(style: style)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    deinit {}

    override func viewDidLoad() {
        observePlaylistLoader()
        super.viewDidLoad()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        observePlaylistLoader()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func observePlaylistLoader() {
        observer?.dispose()
        observer = youtubePlaylistLoader.signal.observe(next: { event in
            switch event {
            case .StartLoading:
                self.showIndicator()
            case .CompleteLoading:
                self.hideIndicator()
                self.tableView.reloadData()
                self.fetchTrackDetails()
            case .FailToLoad:
                break
            }
        })
        tableView.reloadData()
    }

    override func fetchTracks() {
        youtubePlaylistLoader.fetchPlaylistItems(youtubePlaylist)
    }

    override func fetchTrackDetails() {
        for track in tracks {
            track.fetchTrackDetail(false).start(
                next: { (track: Track?) in
                    if let t = track {
                        if let index = find(self.tracks, t) {
                            self.tableView?.reloadRowsAtIndexPaths([NSIndexPath(forItem: index, inSection: 0)],
                                withRowAnimation: UITableViewRowAnimation.None)
                        }
                    }
                    return
                }, error: { error in
                    self.tableView.reloadData()
                }, completed: {
                    self.tableView.reloadData()
            })
        }
    }
}