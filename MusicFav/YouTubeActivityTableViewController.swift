//
//  YouTubeActivityTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 9/5/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import SoundCloudKit
import MusicFeeder

class YouTubeActivityTableViewController: TimelineTableViewController {
    let activityLoader: YouTubeActivityLoader!
    var playlist: YouTubePlaylist!

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
                items.append(TimelineItem.YouTubePlaylist(vals[i], activityLoader.playlistsOfYouTubePlaylist[playlist]?[i]))
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
        return activityLoader.signal.observeNext({ event in
            switch event {
            case .StartLoading:
                self.showIndicator()
            case .CompleteLoading:
                self.hideIndicator()
                self.tableView.reloadData()
            case .FailToLoad:
                self.showReloadButton()
            }
        })
    }
}
