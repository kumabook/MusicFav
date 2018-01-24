//
//  AppleMusicPlaylistRepository.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2018/01/24.
//  Copyright © 2018 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import ReactiveSwift
import MusicFeeder
import MediaPlayer
import Breit

@available(iOS 9.3, *)
class AppleMusicPlaylistRepository {
    enum State {
        case `init`
        case fetching
        case normal
        case error
    }

    enum Event {
        case startLoading
        case completeLoading
        case failToLoad
    }

    var playlists:      [MPMediaPlaylist]

    var state:            State
    var signal:           Signal<Event, NSError>
    var observer:         Signal<Event, NSError>.Observer
    var hasNextPlaylists: Bool

    init() {
        playlists                  = []
        self.state                 = State.init
        let pipe                   = Signal<Event, NSError>.pipe()
        signal                     = pipe.0
        observer                   = pipe.1
        hasNextPlaylists           = true
    }

    fileprivate func fetchNextPlaylists() {
        state = State.fetching
        observer.send(value: .startLoading)
        if let playlists = AppleMusicClient.shared.getPlaylists() {
            self.playlists.append(contentsOf: playlists)
            self.hasNextPlaylists = false
            observer.send(value: .completeLoading)
            self.state = State.normal
        }
    }

    func needFetchPlaylists() -> Bool {
        return hasNextPlaylists
    }

    func fetchPlaylists() {
        if !needFetchPlaylists() { return }
        switch state {
        case .init:     fetchNextPlaylists()
        case .fetching: break
        case .normal:   fetchNextPlaylists()
        case .error:    fetchNextPlaylists()
        }
    }
}
