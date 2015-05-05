//
//  AccessibilityLabel.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 5/5/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation

enum AccessibilityLabel: String {
    case EntryStreamTableView    = "EntryStreamTableView"
    case MenuButton              = "MenuButton"
    case PlaylistStreamTableView = "PlaylistStreamTableView"
    case NewPlaylistButton       = "New Playlist"
    case PlaylistName            = "Playlist name"
    case PlaylistMenuButton      = "Show playlist list"
    case StreamPageMenu          = "StreamPageMenu"
    var s: String { return rawValue }
}