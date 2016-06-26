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
    func notify(event: Event) {
        switch event {
        case .TrackSelected(let track, _, _):
            HistoryStore.add(track as! MusicFeeder.Track)
        default: break
        }
    }
}