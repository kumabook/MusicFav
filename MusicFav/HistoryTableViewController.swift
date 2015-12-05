//
//  HistoryTableViewController.swift
//  MusicFav
//
//  Created by KumamotoHiroki on 10/26/15.
//  Copyright © 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

import UIKit
import MusicFeeder
import Breit

class HistoryTableViewController: StreamTimelineTableViewController {
    var historyLoader: HistoryLoader {
        return streamLoader as! HistoryLoader
    }

    override func getItems() -> [TimelineItem] {
        return historyLoader.histories.flatMap {
            switch $0.type {
            case .Entry:
                let entry = $0.entry!
                return TimelineItem.Entry(entry, historyLoader.playlistsOfHistory[$0])
            case .Track:
                return TimelineItem.TrackHistory($0, historyLoader.playlistsOfHistory[$0])
            }
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAtIndexPath: indexPath)
        if let timelineTableViewCell = cell as? TimelineTableViewCell {
            timelineTableViewCell.prepareSwipeViews(StreamLoader.RemoveMark.Unsave) { cell in
                self.markAsUnsaved(tableView.indexPathForCell(cell)!)
                return
            }
            let history = historyLoader.histories[indexPath.item]
            timelineTableViewCell.dateLabel.text = "\(history.type.actionName) \(history.timestamp.date.passedTime)"
        }
        return cell
    }

    func markAsUnsaved(indexPath: NSIndexPath) {
        let history = historyLoader.histories[indexPath.item]
        HistoryStore.remove(history.toStoreObject())
        historyLoader.histories.removeAtIndex(indexPath.item)
        streamLoader.observer.sendNext(.RemoveAt(indexPath.item))
    }
}