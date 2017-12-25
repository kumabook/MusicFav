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
    var historyRepository: HistoryRepository {
        return entryRepository as! HistoryRepository
    }

    override func getItems() -> [TimelineItem] {
        return historyRepository.histories.flatMap {
            switch $0.type {
            case .Entry:
                guard let entry = $0.entry else { return nil }
                return TimelineItem.entry(entry, historyRepository.playlistsOfHistory[$0])
            case .Track:
                return TimelineItem.trackHistory($0, historyRepository.playlistsOfHistory[$0])
            }
        }
    }
    override func getPlaylistQueue() -> PlaylistQueue {
        return historyRepository.playlistQueue
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if let timelineTableViewCell = cell as? TimelineTableViewCell {
            timelineTableViewCell.prepareSwipeViews(EntryRepository.RemoveMark.unsave) { cell in
                self.markAsUnsaved(tableView.indexPath(for: cell)!)
                return
            }
            let history = historyRepository.histories[indexPath.item]
            timelineTableViewCell.dateLabel.text = "\(history.type.actionName) \(history.timestamp.date.elapsedTime)"
        }
        return cell
    }

    func markAsUnsaved(_ indexPath: IndexPath) {
        let history = historyRepository.histories[indexPath.item]
        HistoryStore.remove(history.toStoreObject())
        historyRepository.histories.remove(at: indexPath.item)
        entryRepository.observer.send(value: .removeAt(indexPath.item))
    }
}
