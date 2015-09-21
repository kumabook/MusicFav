//
//  SoundCloudActivityTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/27/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
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
    override func getItems() -> [TimelineItem] {
        var items: [TimelineItem] = []
        for i in 0..<activityLoader.activities.count {
            items.append(TimelineItem.Activity(activityLoader.activities[i], activityLoader.playlists[i]))
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
        return activityLoader.signal.observeNext({ event in
            switch event {
            case .StartLoadingLatest:
                self.onpuRefreshControl.beginRefreshing()
            case .CompleteLoadingLatest:
                let startTime = dispatch_time(DISPATCH_TIME_NOW, Int64(2.0 * Double(NSEC_PER_SEC)))
                dispatch_after(startTime, dispatch_get_main_queue()) {
                    self.tableView.reloadData()
                    self.onpuRefreshControl.endRefreshing()
                }
            case .StartLoadingNext:
                self.showIndicator()
            case .CompleteLoadingNext:
                self.hideIndicator()
                self.tableView.reloadData()
            case .FailToLoadNext:
                self.showReloadButton()
            case .FailToLoadLatest:
                self.showReloadButton()
            }
        })
    }
}
