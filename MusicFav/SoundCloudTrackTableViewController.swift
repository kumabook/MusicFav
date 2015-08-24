//
//  SoundCloudTrackTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/22/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import MusicFeeder
import SoundCloudKit
import ReactiveCocoa

class SoundCloudTrackTableViewController: TrackTableViewController {
    var observer: Disposable?
    var sctracks: [SoundCloudKit.Track]

    override var playlistType: PlaylistType {
        return .ThirdParty
    }

    override var playlist: MusicFeeder.Playlist {
        return Playlist(title: "Favorites", tracks: tracks)
    }

    override var tracks: [MusicFeeder.Track] {
        return sctracks.map {
            var track = MusicFeeder.Track(provider: .SoundCloud, url: "", identifier: "\($0.id)", title: $0.title)
            track.updateProperties($0)
            return track
        }
    }

    init(tracks: [SoundCloudKit.Track]) {
        sctracks = tracks
        super.init(playlist: Playlist(title: "", tracks: []))
    }

    override init(style: UITableViewStyle) {
        sctracks = []
        super.init(style: style)
    }

    required init(coder aDecoder: NSCoder) {
        sctracks = []
        super.init(coder: aDecoder)
    }

    deinit {}

    override func fetchTracks() {}
}
