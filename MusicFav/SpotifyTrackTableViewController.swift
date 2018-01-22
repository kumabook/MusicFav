//
//  SpotifyTrackTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2018/01/22.
//  Copyright © 2018 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import MusicFeeder
import Spotify
import ReactiveSwift

class SpotifyTrackTableViewController: TrackTableViewController {
    var observer: Disposable?
    var spplaylist: SPTPartialPlaylist!
    
    override var playlistType: PlaylistType {
        return .thirdParty
    }
    
    init(playlist: SPTPartialPlaylist) {
        spplaylist = playlist
        super.init(playlist: Playlist(id: "dummy", title: "", tracks: []))
    }
    
    override init(style: UITableViewStyle) {
        super.init(style: style)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {}
    
    override func fetchTracks() {
        SpotifyAPIClient.shared.playlist(from: spplaylist.uri).on(
            failed: { error in
                print(error)
        }, value: { value in
            guard let items = value.firstTrackPage?.items else { return }
            let tracks: [Track] = items.flatMap { (item: Any) -> [Track] in
                guard let track = item as? SPTPartialTrack else {
                    return []
                }
                return [Track(spotifyTrack: track)]
            }
            self._playlist = Playlist(id: self.playlist.id, title: self.playlist.title, tracks: tracks)
            self.playlistQueue.enqueue(self._playlist)
            self.tableView.reloadData()
        }).start()
    }
}
