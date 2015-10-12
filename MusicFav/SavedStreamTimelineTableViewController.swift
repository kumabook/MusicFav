//
//  SavedStreamTimelineTableViewController.swift
//  MusicFav
//
//  Created by KumamotoHiroki on 10/12/15.
//  Copyright © 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import MusicFeeder

class SavedStreamTimelineTableViewController: StreamTimelineTableViewController {

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAtIndexPath: indexPath)
        if let timelineTableViewCell = cell as? TimelineTableViewCell {
            timelineTableViewCell.prepareSwipeViews(StreamLoader.RemoveMark.Unsave) { cell in
                self.markAsUnsaved(tableView.indexPathForCell(cell)!)
                return
            }
        }
        return cell
    }

    func markAsUnsaved(indexPath: NSIndexPath) {
        streamLoader.markAsUnsaved(indexPath.item)
    }
}
