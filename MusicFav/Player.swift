//  Player.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 3/1/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import AVFoundation

class Observable<T: PlayerObserver>: NSObject {
    var observers: [PlayerObserver] = []
    override init() {
        super.init()
    }
    func addObserver(observer: T) {
        observers.append(observer)
    }
    func removeObserver(observer: T) {
        if let index = find(observers, observer) {
            observers.removeAtIndex(index)
        }
    }
}

let AVQueuePlayerDidChangeStatusNotification: String = "AVQueuePlayerDidChangeStatus"

class AVQueuePlayerNotificationProxy: NSObject {
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if let player = object as? AVQueuePlayer {
            let notificationCenter = NSNotificationCenter.defaultCenter()
            if keyPath  == "status" {
                notificationCenter.postNotificationName(AVQueuePlayerDidChangeStatusNotification, object: player)
            }
        }
    }
}

@objc class ObserverProxy {
    var closure: (NSNotification) -> ();
    var name: String;
    var object: AnyObject?;
    var center: NSNotificationCenter { get { return NSNotificationCenter.defaultCenter() } }
    init(name: String, closure: (NSNotification) -> ()) {
        self.closure = closure;
        self.name = name;
        self.start();
    }
    convenience init(name: String, object: AnyObject, closure: (NSNotification) -> ()) {
        self.init(name: name, closure);
        self.object = object;
    }
    deinit { stop() }
    func start() { center.addObserver(self, selector:"handler:", name:name, object: object); }
    func stop()  { center.removeObserver(self); }
    func handler(notification: NSNotification) { closure(notification); }
}

class PlayerObserver: NSObject, Equatable {
    func timeUpdated() {}
    func didPlayToEndTime() {}
    func statusChanged() {}
    func trackChanged() {}
    func started() {}
    func ended() {}
    func errorOccured() {}
}

func ==(lhs: PlayerObserver, rhs: PlayerObserver) -> Bool {
    return lhs.isEqual(rhs)
}

enum PlayerState {
    case Play
    case Pause
}

@objc class Player<T: PlayerObserver>: Observable<T> {
    private var queuePlayer:  AVQueuePlayer?
    private var playlist:     Playlist?
    private var currentIndex: Int = Int.min
    private var currentTime:  CMTime? { get { return queuePlayer?.currentTime() }}
    private var count:        Int?    { get { return currentPlaylist?.tracks.count }}
    private var timeObserver: AnyObject?
    private var state:        PlayerState
    private var proxy:        AVQueuePlayerNotificationProxy
    private var statusProxy:  ObserverProxy?;
    private var endProxy:     ObserverProxy?;
    override init() {
        state = .Pause
        proxy = AVQueuePlayerNotificationProxy()
        super.init()
        statusProxy = ObserverProxy(name: AVQueuePlayerDidChangeStatusNotification, closure: self.playerDidChangeStatus);
        endProxy    = ObserverProxy(name: AVPlayerItemDidPlayToEndTimeNotification, closure: self.playerDidPlayToEndTime);
    }

    deinit {
        statusProxy?.stop()
        endProxy?.stop()
        statusProxy = nil
        endProxy    = nil
    }

    func timeUpdated() {
        for o in observers { o.timeUpdated() }
    }
    func didPlayToEndTime()        { for o in observers { o.didPlayToEndTime() }}
    func statusChanged()           { for o in observers { o.statusChanged() }}
    func trackChanged()            { for o in observers { o.trackChanged() }}
    func started()                 { for o in observers { o.started() }}
    func ended()                   { for o in observers { o.ended() }}
    func errorOccured()            { for o in observers { o.errorOccured() }}

    var avPlayer:         AVPlayer?   { get { return queuePlayer }}
    var playerItemsCount: Int?        { get { return queuePlayer?.items().count }}
    var currentPlaylist:  Playlist?   { get { return playlist }}
    var currentTrack:     Track?      { get { return playlist?.tracks[currentIndex] }}
    var currentState:     PlayerState { get { return state }}
    var secondPair:       (Float64, Float64)? {
        get {
            if let count = playerItemsCount {
                if count == 0 { return nil }
                if let item = queuePlayer?.currentItem {
                    return (CMTimeGetSeconds(item.currentTime()), CMTimeGetSeconds(item.duration))
                }
            }
            return nil
        }
    }

    func play(index: Int, playlist: Playlist) {
        if let _playlist = currentPlaylist {
            if self.currentIndex == index && _playlist.id == playlist.id {
                if let player = self.queuePlayer {
                    if player.items().count > 0 {
                        player.play()
                        state = .Play
                    }
                }
                return
            }
        }
        self.playlist = playlist
        let count            = playlist.tracks.count
        self.currentIndex    = index % count
        if let player = self.queuePlayer {
            player.pause()
            player.removeTimeObserver(self.timeObserver)
            player.removeAllItems()
            player.removeObserver(self.proxy, forKeyPath: "status")
        }

        var _playerItems: [AVPlayerItem] = []
        for i in 0..<count {
            if let url = playlist.tracks[(index + i) % count].streamUrl {
                _playerItems.append(AVPlayerItem(URL:url))
            }
        }
        let player = AVQueuePlayer(items: _playerItems)
        self.queuePlayer = player
        player.seekToTime(kCMTimeZero)
        var time = CMTimeMakeWithSeconds(1.0, 1)
        self.timeObserver = player.addPeriodicTimeObserverForInterval(time, queue:nil, usingBlock:self.updateTime)
        player.addObserver(self.proxy, forKeyPath: "status", options: NSKeyValueObservingOptions.allZeros, context: nil)
        player.play()
        state = .Play
    }

    func toggle() {
        if currentIndex == Int.min || queuePlayer == nil || playlist == nil {
            return
        }
        switch state {
        case .Pause:
            play(currentIndex, playlist: currentPlaylist!)
        case .Play:
            queuePlayer!.pause()
            state = .Pause
        }
    }

    func previous() {
        if currentIndex == Int.min || playlist == nil {
            return
        }
        switch state {
        case .Pause:
            currentIndex -= 1
            statusChanged()
        case .Play:
            play(currentIndex - 1, playlist: currentPlaylist!)
        }
    }

    func next() {
        if currentIndex == Int.min || playlist == nil {
            return
        }
        switch state {
        case .Pause:
            currentIndex = (currentIndex + 1) % count!
            statusChanged()
        case .Play:
            play(currentIndex + 1 % count!, playlist: currentPlaylist!)
        }
    }

    func playerDidPlayToEndTime(notification: NSNotification) {
        if playlist == nil {
            return
        }
        queuePlayer!.removeItem(queuePlayer!.currentItem)
        currentIndex = (currentIndex + 1) % count!
        ended()
    }

    func playerDidChangeStatus(notification: NSNotification) {
        if playlist == nil {
            return
        }
        if let player = queuePlayer {
            switch player.status {
            case .ReadyToPlay: started()
            case .Failed:      errorOccured()
            case .Unknown:     errorOccured()
            }
        }
    }

    func updateTime(time: CMTime) {
        if let player = queuePlayer {
            timeUpdated()
        }
    }

    func seekToTime(time: CMTime) {
        queuePlayer?.seekToTime(time)
    }
}
