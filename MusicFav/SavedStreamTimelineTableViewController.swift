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

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if let timelineTableViewCell = cell as? TimelineTableViewCell {
            timelineTableViewCell.prepareSwipeViews(EntryRepository.RemoveMark.unsave) { cell in
                self.markAsUnsaved(tableView.indexPath(for: cell)!)
                return
            }
        }
        return cell
    }

    func markAsUnsaved(_ indexPath: IndexPath) {
        entryRepository.markAsUnsaved(indexPath.item)
    }
}
