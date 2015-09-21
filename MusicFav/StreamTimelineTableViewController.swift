//
//  StreamTimelineTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 9/1/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import SwiftyJSON
import FeedlyKit
import MusicFeeder

class StreamTimelineTableViewController: TimelineTableViewController {
    var streamLoader: StreamLoader!

    init(streamLoader: StreamLoader) {
        self.streamLoader = streamLoader
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
    }

    deinit {
        observer?.dispose()
    }

    override var timelineTitle: String { return streamLoader.stream.streamTitle }

    override func getItems() -> [TimelineItem] {
        return streamLoader.entries.map { TimelineItem.Entry($0, self.streamLoader.playlistsOfEntry[$0]) }
    }

    override func fetchLatest() {
        streamLoader.fetchLatestEntries()
    }

    override func fetchNext() {
        streamLoader.fetchEntries()
    }

    override func observeTimelineLoader() -> Disposable? {
        return streamLoader.signal.observeNext({ event in
            switch event {
            case .StartLoadingLatest:
                self.onpuRefreshControl.beginRefreshing()
            case .CompleteLoadingLatest:
                let startTime = dispatch_time(DISPATCH_TIME_NOW, Int64(2.0 * Double(NSEC_PER_SEC)))
                dispatch_after(startTime, dispatch_get_main_queue()) {
                    self.tableView.reloadData()
                    self.onpuRefreshControl.endRefreshing()
                    self.updateSelection(UITableViewScrollPosition.None)
                }
            case .StartLoadingNext:
                self.showIndicator()
            case .CompleteLoadingNext:
                self.hideIndicator()
                self.tableView.reloadData()
                self.updateSelection(UITableViewScrollPosition.None)
            case .FailToLoadNext:
                self.showReloadButton()
            case .CompleteLoadingPlaylist(_, let entry):
                let items = self.getItems()
                for i in 0..<items.count {
                    if entry == items[i].entry && i < self.tableView.numberOfRowsInSection(0) {
                        let index = NSIndexPath(forItem: i, inSection: 0)
                        self.tableView.reloadRowsAtIndexPaths([index], withRowAnimation: .None)
                    }
                }
                self.updateSelection(UITableViewScrollPosition.None)
            case .RemoveAt(let index):
                let indexPath = NSIndexPath(forItem: index, inSection: 0)
                self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            }
        })
    }
}
