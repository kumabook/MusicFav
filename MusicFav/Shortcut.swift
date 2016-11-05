//
//  Shortcut.swift
//  MusicFav
//
//  Created by KumamotoHiroki on 10/4/15.
//  Copyright © 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import UIKit
import MusicFeeder
import PlayerKit

class ShortcutPlayerObserver: PlayerObserver {
    override func listen(_ event: PlayerEvent) {
        switch event {
        case .timeUpdated:               break
        case .didPlayToEndTime:          break
        case .statusChanged:             break
        case .trackSelected:             update()
        case .trackUnselected:           update()
        case .previousPlaylistRequested: update()
        case .nextPlaylistRequested:     update()
        case .errorOccured:              update()
        case .playlistChanged:           update()
        case .nextTrackAdded:            update()
        }
    }
    func update() {
        Shortcut.updateShortcutItems(UIApplication.shared)
    }
}

enum Shortcut: String {
    static let delaySec = 1.0
    static let appDelegate = UIApplication.shared.delegate as! AppDelegate
    case Play     = "Play"
    case Pause    = "Pause"
    case Playlist = "Playlist"
    case Favorite = "Favorite"

    init?(fullType: String) {
        guard let last = fullType.components(separatedBy: ".").last else { return nil }
        self.init(rawValue: last)
    }

    var type: String {
        return Bundle.main.bundleIdentifier! + ".\(self.rawValue)"
    }

    var title: String {
        switch self {
        case .Play:     return "Play".localize()
        case .Pause:    return "Pause".localize()
        case .Playlist: return "Playlist".localize()
        case .Favorite: return "Favorite".localize()
        }
    }

    var subtitle: String {
        switch self {
        case .Play:
            if let title = Shortcut.appDelegate.player?.currentTrack?.title {
                return title
            } else {
                return "No track".localize()
            }
        case .Pause:    return ""
        case .Playlist:
            if let playlist = Shortcut.appDelegate.player?.currentPlaylist as? MusicFeeder.Playlist {
                return playlist.title
            } else {
                return "No playlist".localize()
            }
        case .Favorite: return "Save the track".localize()
        }
    }

    var userInfo: [String : NSSecureCoding]? {
        return [:]
    }

    @available(iOS 9.0, *)
    var icon: UIApplicationShortcutIcon {
        switch self {
        case .Play:     return UIApplicationShortcutIcon(type: .play)
        case .Pause:    return UIApplicationShortcutIcon(type: .pause)
        case .Playlist: return UIApplicationShortcutIcon(templateImageName: "playlist")
        case .Favorite: return UIApplicationShortcutIcon(templateImageName: "fav_playlist")
        }
    }

    @available(iOS 9.0, *)
    var item: UIMutableApplicationShortcutItem {
        return UIMutableApplicationShortcutItem(type: type,
                                      localizedTitle: title,
                                   localizedSubtitle: subtitle,
                                                icon: icon,
                                            userInfo: userInfo)
    }

    @available(iOS 9.0, *)
    var currentItem: UIApplicationShortcutItem? {
        for shortcut in UIApplication.shared.shortcutItems ?? [] where shortcut.type == type {
            return shortcut
        }
        return nil
    }

    @available(iOS 9.0, *)
    func handleShortCutItem() -> Bool {
        let app = Shortcut.appDelegate
        switch self {
        case .Play:
            app.play()
            return true
        case .Pause:
            app.pause()
            return true
        case .Playlist:
            let vc = app.miniPlayerViewController
            if let playlist = app.playingPlaylist {
                app.mainViewController?.showRightPanelAnimated(true) {
                    let _ = vc?.playlistTableViewController.showPlaylist(playlist, animated: false)
                    return
                }
            } else {
                app.mainViewController?.showRightPanelAnimated(true) {}
            }
            return true
        case .Favorite:
            let vc = app.miniPlayerViewController
            if let track = app.player?.currentTrack, let playlist = app.playingPlaylist {
                app.mainViewController?.showRightPanelAnimated(false) {
                    if let tvc = vc?.playlistTableViewController.showPlaylist(playlist, animated: false) {
                        tvc.showSelectPlaylistViewController([track as! MusicFeeder.Track])
                    }
                }
            } else {
                app.mainViewController?.showRightPanelAnimated(true) {}
            }
            return true
        }
    }

    static func updateShortcutItems(_ application: UIApplication) {
        if #available(iOS 9.0, *) {
            application.shortcutItems = [Shortcut.Play.item, Shortcut.Pause.item, Shortcut.Playlist.item, Shortcut.Favorite.item]
        }
    }

    static func observePlayer(_ player: Player) {
        let observer = ShortcutPlayerObserver()
        appDelegate.player?.addObserver(observer)
    }
}
