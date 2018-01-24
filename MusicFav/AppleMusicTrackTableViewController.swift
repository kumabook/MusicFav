//
//  AppleMusicTrackTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2018/01/24.
//  Copyright © 2018 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import UIKit
import MusicFeeder
import MediaPlayer
import ReactiveSwift

@available(iOS 10.3, *)
class AppleMusicTrackTableViewController: TrackTableViewController {
    var observer: Disposable?
    var mediaPlaylist: MPMediaPlaylist!
    
    override var playlistType: PlaylistType {
        return .thirdParty
    }
    
    override var tracks: [MusicFeeder.Track] {
        return mediaPlaylist.items.map { Track(item: $0) }
    }
    
    init(playlist: MPMediaPlaylist) {
        mediaPlaylist = playlist
        super.init(playlist: Playlist(id: "apple-music-playlist-\(playlist.persistentID)",
                                   title: playlist.name ?? "",
                                  tracks: mediaPlaylist.items.map { Track(item: $0) }))
    }
    
    override init(style: UITableViewStyle) {
        super.init(style: style)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {}
    
    override func fetchTracks() {}

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.tableCellReuseIdentifier, for: indexPath) as! TrackTableViewCell
        let track = tracks[indexPath.item]
        let item = mediaPlaylist.items[indexPath.item]
        cell.trackNameLabel.text = item.title
        let minutes = Int(floor(track.duration / 60))
        let seconds = Int(round(track.duration - Double(minutes) * 60))
        cell.durationLabel.text = String(format: "%.2d:%.2d", minutes, seconds)
        if let image = item.artwork?.image(at: cell.thumbImgView.frame.size) {
            cell.thumbImgView.image = image
        } else {
            cell.thumbImgView.image = UIImage(named: "default_thumb")
        }
        if isTrackPlaying(track) {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: UITableViewScrollPosition.none)
        }
        return cell
    }
}
