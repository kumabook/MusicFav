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
    func notify(_ event: Event) {
        switch event {
        case .trackSelected(let track, _, _):
            let _  = HistoryStore.add(track as! MusicFeeder.Track)
        default: break
        }
    }
}
