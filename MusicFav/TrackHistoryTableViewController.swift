//
//  TrackHistoryTableViewController.swift
//  MusicFav
//
//  Created by KumamotoHiroki on 10/25/15.
//  Copyright © 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation

import UIKit
import MusicFeeder
import Breit

class TrackHistoryTableViewController: StreamTimelineTableViewController {
    var trackHistoryLoader: TrackHistoryLoader {
        return streamLoader as! TrackHistoryLoader
    }

    override func getItems() -> [TimelineItem] {
        return trackHistoryLoader.histories.map {
            TimelineItem.TrackHistory($0,
                Playlist(id: "track_history_\($0.timestamp)",
                      title: $0.track.title ?? "",
                     tracks: [$0.track]))
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAtIndexPath: indexPath)
        if let timelineTableViewCell = cell as? TimelineTableViewCell {
            timelineTableViewCell.prepareSwipeViews(StreamLoader.RemoveMark.Unsave) { cell in
                self.markAsUnsaved(tableView.indexPathForCell(cell)!)
                return
            }
            let history = trackHistoryLoader.histories[indexPath.item]
            timelineTableViewCell.dateLabel.text = history.timestamp.date.passedTime
        }
        return cell
    }

    func markAsUnsaved(indexPath: NSIndexPath) {
        let history = trackHistoryLoader.histories[indexPath.item]
        TrackHistoryStore.remove(history.toStoreObject())
        streamLoader.entries.removeAtIndex(indexPath.item)
        trackHistoryLoader.histories.removeAtIndex(indexPath.item)
        streamLoader.sink(.Next(.RemoveAt(indexPath.item)))
    }
}
