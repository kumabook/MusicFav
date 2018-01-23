//
//  SpotifyTopTracksTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2018/01/22.
//  Copyright © 2018 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveSwift
import MusicFeeder

class SpotifyTopTracksTableViewController: TimelineTableViewController {
    var spotifyTopItemRepository = SpotifyTopItemRepository()

    override init() {
        super.init()
    }
    
    override init(style: UITableViewStyle) {
        super.init(style: style)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
    }
    
    override var timelineTitle: String { return "Spotify Top Tracks" }
    override func getItems() -> [TimelineItem] {
        return spotifyTopItemRepository.tracks.enumerated().map { v in
            TimelineItem.spotifyTopTrack(v.element, spotifyTopItemRepository.playlistQueue.playlists[v.offset] as? Playlist)
        }
    }
    override func getPlaylistQueue() -> PlaylistQueue {
        return spotifyTopItemRepository.playlistQueue
    }
    
    override func fetchNext() {
        spotifyTopItemRepository.fetchItems()
    }
    
    override func fetchLatest() {
        spotifyTopItemRepository.fetchLatestItems()
    }
    
    override func observeTimelineLoader() -> Disposable? {
        return spotifyTopItemRepository.signal.observeResult({ result in
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
