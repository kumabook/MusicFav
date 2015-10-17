//
//  EntryHistoryTableViewController.swift
//  MusicFav
//
//  Created by KumamotoHiroki on 10/12/15.
//  Copyright © 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import MusicFeeder
import Breit

class EntryHistoryTableViewController: StreamTimelineTableViewController {
    var entryHistoryLoader: EntryHistoryLoader {
        return streamLoader as! EntryHistoryLoader
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAtIndexPath: indexPath)
        
        if let timelineTableViewCell = cell as? TimelineTableViewCell {
            timelineTableViewCell.prepareSwipeViews(StreamLoader.RemoveMark.Unsave) { cell in
                self.markAsUnsaved(tableView.indexPathForCell(cell)!)
                return
            }
            let history = entryHistoryLoader.histories[indexPath.item]
            timelineTableViewCell.dateLabel.text = history.timestamp.date.passedTime
        }
        return cell
    }
    
    func markAsUnsaved(indexPath: NSIndexPath) {
        let history = entryHistoryLoader.histories[indexPath.item]
        EntryHistoryStore.remove(history.toStoreObject())
        streamLoader.entries.removeAtIndex(indexPath.item)
        entryHistoryLoader.histories.removeAtIndex(indexPath.item)
        streamLoader.sink(.Next(.RemoveAt(indexPath.item)))
    }
}
