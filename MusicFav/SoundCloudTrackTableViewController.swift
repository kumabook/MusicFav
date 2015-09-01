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
        return Playlist(id: "soundcloud-favorites", title: "Favorites", tracks: tracks)
    }

    override var tracks: [MusicFeeder.Track] {
        return sctracks.map { $0.toTrack() }
    }

    init(tracks: [SoundCloudKit.Track]) {
        sctracks = tracks
        super.init(playlist: Playlist(id: "soundcloud-favorites", title: "Favorites", tracks: []))
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
