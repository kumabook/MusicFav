//
//  YouTubeActivityTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 9/5/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveSwift
import SoundCloudKit
import MusicFeeder

class YouTubeActivityTableViewController: TimelineTableViewController {
    let activityLoader: YouTubeActivityLoader!
    var playlist: YouTubePlaylist!
    override func getPlaylistQueue() -> PlaylistQueue {
        return activityLoader.playlistQueue
    }

   init(activityLoader: YouTubeActivityLoader, playlist: YouTubePlaylist) {
        self.activityLoader = activityLoader
        self.playlist       = playlist
        super.init()
    }

    override init(style: UITableViewStyle) {
        activityLoader = YouTubeActivityLoader()
        super.init(style: style)
    }

    required init?(coder aDecoder: NSCoder) {
        activityLoader = YouTubeActivityLoader()
        super.init(coder:aDecoder)
    }

    override var timelineTitle: String {
        return playlist.title.localize()
    }

    override func getItems() -> [TimelineItem] {
        var items: [TimelineItem] = []
        if let vals = activityLoader.itemsOfPlaylist[playlist] {
            for i in 0..<vals.count {
                items.append(TimelineItem.youTubePlaylist(vals[i], activityLoader.playlistsOfYouTubePlaylist[playlist]?[i]))
            }
        }
        return items
    }

    override func fetchNext() {
        activityLoader.fetchPlaylistItems(playlist)
    }

    override func fetchLatest() {
        activityLoader.clearPlaylist(playlist)
        activityLoader.fetchPlaylistItems(playlist)
    }

    override func observeTimelineLoader() -> Disposable? {
        return activityLoader.signal.observeResult({ result in
            guard let event = result.value else { return }
            switch event {
            case .startLoading:
                self.showIndicator()
            case .completeLoading:
                self.hideIndicator()
                self.tableView.reloadData()
            case .failToLoad:
                self.showReloadButton()
            }
        })
    }
}
