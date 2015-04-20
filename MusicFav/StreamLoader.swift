//
//  StreamLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/4/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import FeedlyKit
import ReactiveCocoa
import LlamaKit

class StreamLoader {
    enum RemoveMark {
        case Read
        case Unread
        case Unsave
    }

    enum State {
        case Normal
        case Fetching
        case Complete
        case Error
    }

    enum Event {
        case StartLoadingLatest
        case CompleteLoadingLatest
        case StartLoadingNext
        case CompleteLoadingNext
        case FailToLoadNext
        case CompleteLoadingPlaylist(Playlist, Entry)
        case RemoveAt(Int)
    }

    let feedlyClient     = CloudAPIClient.sharedInstance
    let musicfavClient   = MusicFavAPIClient.sharedInstance

    let stream:             Stream
    var lastUpdated:        Int64
    var state:              State
    var entries:            [Entry]
    var playlistsOfEntry:   [Entry:Playlist]
    var loaderOfPlaylist:   [Playlist:(PlaylistLoader, Disposable)]
    var playlistifier:      Disposable?
    var streamContinuation: String?
    var hotSignal:          HotSignal<Event>
    var sink:               SinkOf<Event>

    init(stream: Stream) {
        self.stream      = stream
        state            = .Normal
        lastUpdated      = 0
        entries          = []
        playlistsOfEntry = [:]
        loaderOfPlaylist = [:]
        let pipe = HotSignal<Event>.pipe()
        hotSignal        = pipe.0
        sink             = pipe.1
    }

    deinit {
        dispose()
    }

    func dispose() {
        for loader in loaderOfPlaylist {
            loader.1.1.dispose()
        }
        playlistifier?.dispose()
    }

    func updateLastUpdated(updated: Int64?) {
        if let timestamp = updated {
            self.lastUpdated = timestamp + 1
        } else {
            self.lastUpdated = Int64(NSDate().timeIntervalSince1970 * 1000)
        }
    }

    func fetchLatestEntries() {
        if entries.count == 0 {
            return
        }

        var signal: ColdSignal<PaginatedEntryCollection>
        signal = feedlyClient.fetchEntries(streamId: stream.streamId,
                                          newerThan: lastUpdated,
                                         unreadOnly: unreadOnly)
        sink.put(.StartLoadingLatest)
        signal.deliverOn(MainScheduler())
            .start(
                next: { paginatedCollection in
                    var latestEntries = paginatedCollection.items
                    self.playlistifier = latestEntries.map({
                        self.loadPlaylistOfEntry($0)
                    }).reduce(ColdSignal<Void>.empty(), combine: { (signal, nextSignal) in
                        signal.concat(nextSignal)
                    }).start(next: {}, error: {error in}, completed: {})
                    latestEntries.extend(self.entries)
                    self.entries = latestEntries
                    self.updateLastUpdated(paginatedCollection.updated)
                },
                error: {error in
                    let key = "com.alamofire.serialization.response.error.response"
                    if let dic = error.userInfo as NSDictionary? {
                        if let response:NSHTTPURLResponse = dic[key] as? NSHTTPURLResponse {
                            if response.statusCode == 401 {
                                FeedlyAPI.clearAllAccount()
                                //TODO: Alert Dialog with login link
                            } else {
                            }
                        } else {
                        }
                    }
                },
                completed: {
                    self.sink.put(.CompleteLoadingLatest)
            })
    }

    func fetchEntries() {
        if state == .Fetching || state == .Complete {
            return
        }
        state = .Fetching
        sink.put(.StartLoadingNext)
        var signal: ColdSignal<PaginatedEntryCollection>
        signal = feedlyClient.fetchEntries(streamId:stream.streamId, continuation: streamContinuation, unreadOnly: unreadOnly)
        signal.deliverOn(MainScheduler())
            .start(
                next: {paginatedCollection in
                    let entries = paginatedCollection.items
                    self.entries.extend(entries)
                    self.playlistifier = entries.map({
                        self.loadPlaylistOfEntry($0)
                    }).reduce(ColdSignal<Void>.empty(), combine: { (signal, nextSignal) in
                        signal.concat(nextSignal)
                    }).start(next: {}, error: {error in}, completed: {})
                    self.streamContinuation = paginatedCollection.continuation
                    self.updateLastUpdated(paginatedCollection.updated)
                    self.sink.put(.CompleteLoadingNext)           // First reload tableView,
                    if paginatedCollection.continuation == nil {  // then wait for next load
                        self.state = .Complete
                    } else {
                        self.state = .Normal
                    }
                },
                error: {error in
                    let key = "com.alamofire.serialization.response.error.response"
                    if let dic = error.userInfo as NSDictionary? {
                        if let response:NSHTTPURLResponse = dic[key] as? NSHTTPURLResponse {
                            if response.statusCode == 401 {
                                FeedlyAPI.clearAllAccount()
                                //TODO: Alert Dialog with login link
                            } else {
                                self.state = State.Error
                                self.sink.put(.FailToLoadNext)
                            }
                        } else {
                            self.state = State.Error
                            self.sink.put(.FailToLoadNext)
                        }
                    }
                },
                completed: {
            })
    }

    func loadPlaylistOfEntry(entry: Entry) -> ColdSignal<Void> {
        if let url = entry.url {
            return musicfavClient.playlistify(url).map({ playlist in
                self.playlistsOfEntry[entry] = playlist
                MainScheduler().schedule {
                    self.sink.put(.CompleteLoadingPlaylist(playlist, entry))
                }
                if let _disposable = self.loaderOfPlaylist[playlist] {
                    _disposable.1.dispose()
                }
                let loader = PlaylistLoader(playlist: playlist)
                let disposable = loader.fetchTracks().start(next: { track in
                    }, error: { error in
                        println(error)
                    }, completed: {
                })
                self.loaderOfPlaylist[playlist] = (loader, disposable)
                return ()
            })
        }
        return ColdSignal<Void>.empty()
    }

    var unreadOnly: Bool {
        if let userId = FeedlyAPI.profile?.id {
            if stream == Tag.Saved(userId) { return false }
            if stream == Tag.Read(userId) {  return false }
        }
        return true
    }

    var removeMark: RemoveMark {
        if let userId = FeedlyAPI.profile?.id {
            if stream == Tag.Saved(userId) { return .Unsave }
            if stream == Tag.Read(userId)  { return .Unread }
        }
        return .Read
    }

    func markAsRead(index: Int) {
        let entry = entries[index]
        if feedlyClient.isLoggedIn {
            feedlyClient.markEntriesAsRead([entry.id], completionHandler: { (req, res, error) -> Void in
                if let e = error { println("Failed to mark as read") }
                else             { println("Succeeded in marking as read") }
            })
        }
        entries.removeAtIndex(index)
        sink.put(.RemoveAt(index))
    }

    func markAsUnread(index: Int) {
        let entry = entries[index]
        if feedlyClient.isLoggedIn {
            feedlyClient.keepEntriesAsUnread([entry.id], completionHandler: { (req, res, error) -> Void in
                if let e = error { println("Failed to mark as unread") }
                else             { println("Succeeded in marking as unread") }
            })
        }
        entries.removeAtIndex(index)
        sink.put(.RemoveAt(index))
    }

    func markAsUnsaved(index: Int) {
        let entry = entries[index]
        if feedlyClient.isLoggedIn {
            feedlyClient.markEntriesAsUnsaved([entry.id], completionHandler: { (req, res, error) -> Void in
                if let e = error { println("Failed to mark as unsaved") }
                else             { println("Succeeded in marking as unsaved") }
            })
            feedlyClient.markEntriesAsRead([entry.id], completionHandler: { (req, res, error) -> Void in
                if let e = error { println("Failed to mark as read") }
                else             { println("Succeeded in marking as read") }
            })
        }
        entries.removeAtIndex(index)
        sink.put(.RemoveAt(index))
    }
}
