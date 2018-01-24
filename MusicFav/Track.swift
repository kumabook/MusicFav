//
//  Track.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2018/01/22.
//  Copyright © 2018 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import MediaPlayer
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
    @available(iOS 10.3, *)
    convenience init(item: MPMediaItem) {
        let country = Track.appleMusicCurrentCountry ?? "US"
        var url = ""
        if item.playbackStoreID != "0" {
            url = "https://geo.itunes.apple.com/\(country)/xxxx/xxxx/\(item.playbackStoreID)"
        }
        self.init(id:           "\(item.persistentID)",
                  provider:     .appleMusic,
                  url:          url,
                  identifier:   item.playbackStoreID,
                  title:        item.title,
                  duration:     item.playbackDuration,
                  thumbnailUrl: nil,
                  artworkUrl:   nil,
                  audioUrl:     item.assetURL,
                  ownerId:      nil,
                  ownerName:    item.artist,
                  status:       Track.Status.available,
                  expiresAt:    Int64.max,
                  publishedAt:  Int64.max,
                  createdAt:    Date().timestamp,
                  updatedAt:    Date().timestamp,
                  state:        EnclosureState.alive,
                  isLiked:      nil,
                  isSaved:      nil,
                  isPlayed:     nil)
        mediaItem = item
    }
}
