//
//  StreamTimelineTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 9/1/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveSwift
import SwiftyJSON
import FeedlyKit
import MusicFeeder

class StreamTimelineTableViewController: TimelineTableViewController {
    var entryRepository: EntryRepository!

    init(entryRepository: EntryRepository) {
        self.entryRepository = entryRepository
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
    }

    deinit {
        observer?.dispose()
    }

    override var timelineTitle: String { return entryRepository.stream.streamTitle }

    override func getItems() -> [TimelineItem] {
        return entryRepository.items.map { TimelineItem.entry($0, self.entryRepository.playlistsOfEntry[$0]) }
    }
    override func getPlaylistQueue() -> PlaylistQueue {
        return entryRepository.playlistQueue
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
        if entryRepository.state == EntryRepository.State.error {
            entryRepository.fetchLatestItems()
        }
        entryRepository.fetchAllPlaylists()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func fetchLatest() {
        entryRepository.fetchLatestItems()
    }

    override func fetchNext() {
        entryRepository.fetchItems()
    }

    override func observeTimelineLoader() -> Disposable? {
        return entryRepository.signal.observeResult({ result in
            guard let event = result.value else { return }
            switch event {
            case .startLoadingCache:
                self.showIndicator()
            case .completeLoadingCache:
                self.tableView.reloadData()
            case .startLoadingLatest:
                self.onpuRefreshControl.beginRefreshing()
            case .completeLoadingLatest:
                self.tableView.reloadData()
                self.onpuRefreshControl.endRefreshing()
                self.updateSelection(UITableViewScrollPosition.none)
            case .startLoadingNext:
                self.showIndicator()
            case .completeLoadingNext:
                self.hideIndicator()
                self.tableView.reloadData()
                self.updateSelection(UITableViewScrollPosition.none)
            case .failToLoadNext:
                self.showReloadButton()
            case .completeLoadingPlaylist(_, let entry):
                let items = self.getItems()
                for i in 0..<items.count {
                    if entry == items[i].entry && i < self.tableView.numberOfRows(inSection: 0) {
                        let index = IndexPath(item: i, section: 0)
                        self.tableView.reloadRows(at: [index], with: .none)
                    }
                }
                self.updateSelection(UITableViewScrollPosition.none)
            case .removeAt(let index):
                let indexPath = IndexPath(item: index, section: 0)
                self.tableView.deleteRows(at: [indexPath], with: .fade)
            case .completeLoadingTrackDetail(_):
                break
            }
        })
    }
}
