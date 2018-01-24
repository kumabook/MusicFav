//
//  Track.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2018/01/22.
//  Copyright © 2018 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import Spotify
import MusicFeeder

extension Track {
    convenience init(spotifyTrack spt: SPTPartialTrack) {
        self.init(id:           spt.uri.absoluteString,
                  provider:     .spotify,
                  url:          spt.uri.absoluteString,
                  identifier:   spt.identifier,
                  title:        spt.name,
                  duration:     spt.duration,
                  thumbnailUrl: spt.album?.smallestCover?.imageURL,
                  artworkUrl:   spt.album?.largestCover?.imageURL,
                  audioUrl:     spt.previewURL,
                  ownerId:      spt.artists.get(0).flatMap { $0 as? SPTPartialArtist }.flatMap { $0.identifier },
                  ownerName:    spt.artists.get(0).flatMap { $0 as? SPTPartialArtist }.flatMap { $0.name },
                  status:       .available)
    }
    convenience init(spotifyTrack spt: SPTPartialTrack, spotifyAlbum album: SPTAlbum) {
        self.init(id:           spt.uri.absoluteString,
                  provider:     .spotify,
                  url:          spt.uri.absoluteString,
                  identifier:   spt.identifier,
                  title:        spt.name,
                  duration:     spt.duration,
                  thumbnailUrl: album.smallestCover?.imageURL,
                  artworkUrl:   album.largestCover?.imageURL,
                  audioUrl:     spt.previewURL,
                  ownerId:      spt.artists.get(0).flatMap { $0 as? SPTPartialArtist }.flatMap { $0.identifier },
                  ownerName:    spt.artists.get(0).flatMap { $0 as? SPTPartialArtist }.flatMap { $0.name },
                  status:       .available)
    }
}
