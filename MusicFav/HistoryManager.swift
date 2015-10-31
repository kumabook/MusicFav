//
//  HistoryManager.swift
//  MusicFav
//
//  Created by KumamotoHiroki on 10/26/15.
//  Copyright © 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import PlayerKit
import MusicFeeder

class HistoryManager: PlayerObserver {
    override func timeUpdated() {}
    override func didPlayToEndTime() {}
    override func statusChanged() {}
    override func trackUnselected(track: PlayerKit.Track, index: Int, playlist: PlayerKit.Playlist) {}
    override func previousPlaylistRequested() {}
    override func nextPlaylistRequested() {}
    override func errorOccured() {}
    override func trackSelected(track: PlayerKit.Track, index: Int, playlist: PlayerKit.Playlist) {
        HistoryStore.add(track as! MusicFeeder.Track)
    }
}