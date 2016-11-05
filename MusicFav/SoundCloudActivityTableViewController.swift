//
//  SoundCloudActivityTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/27/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveSwift
import SoundCloudKit
import MusicFeeder

class SoundCloudActivityTableViewController: TimelineTableViewController {
    let activityLoader: SoundCloudActivityLoader!

    override init() {
        activityLoader = SoundCloudActivityLoader()
        super.init()
    }

    override init(style: UITableViewStyle) {
        activityLoader = SoundCloudActivityLoader()
        super.init(style: style)
    }

    required init?(coder aDecoder: NSCoder) {
        activityLoader = SoundCloudActivityLoader()
        super.init(coder:aDecoder)
    }

    override var timelineTitle: String { return "SoundCloud" }
    override func getPlaylistQueue() -> PlaylistQueue {
        return activityLoader.playlistQueue
    }
    override func getItems() -> [TimelineItem] {
        var items: [TimelineItem] = []
        for i in 0..<activityLoader.activities.count {
            items.append(TimelineItem.activity(activityLoader.activities[i], activityLoader.playlists[i]))
        }
        return items
    }

    override func fetchNext() {
        activityLoader.fetchActivities()
    }

    override func fetchLatest() {
        activityLoader.fetchLatestActivities()
    }

    override func observeTimelineLoader() -> Disposable? {
        return activityLoader.signal.observeResult({ result in
            guard let event = result.value else { return }
            switch event {
            case .startLoadingLatest:
                self.onpuRefreshControl.beginRefreshing()
            case .completeLoadingLatest:
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.tableView.reloadData()
                    self.onpuRefreshControl.endRefreshing()
                }
            case .startLoadingNext:
                self.showIndicator()
            case .completeLoadingNext:
                self.hideIndicator()
                self.tableView.reloadData()
            case .failToLoadNext:
                self.showReloadButton()
            case .failToLoadLatest:
                self.showReloadButton()
            }
        })
    }
}
