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
    class func defaultStream() -> Stream {
        if let profile = FeedlyAPIClient.sharedInstance.profile {
            return FeedlyKit.Category.All(profile.id)
        } else {
            return StreamListLoader.sampleSubscriptions()[0]
        }
    }

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

    let feedlyClient     = FeedlyAPIClient.sharedInstance
    let musicfavClient   = MusicFavAPIClient.sharedInstance

    let stream:             Stream
    var lastUpdated:        Int64
    var state:              State
    var entries:            [Entry]
    var playlistsOfEntry:   [Entry:Playlist]
    var loaderOfPlaylist:   [Playlist:(PlaylistLoader, Disposable)]
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
            let disposable = loader.1.1
            if !disposable.disposed {
                loader.1.1.dispose()
            }
        }
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
                    let entries = paginatedCollection.items
                    for e in entries {
                        self.entries.insert(e, atIndex: 0)
                        self.loadPlaylistOfEntry(e)
                    }
                    self.updateLastUpdated(paginatedCollection.updated)
                },
                error: {error in
                    let key = "com.alamofire.serialization.response.error.response"
                    if let dic = error.userInfo as NSDictionary? {
                        if let response:NSHTTPURLResponse = dic[key] as? NSHTTPURLResponse {
                            if response.statusCode == 401 {
                                self.feedlyClient.clearAllAccount()
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
                    for e in entries { self.loadPlaylistOfEntry(e) }
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
                                self.feedlyClient.clearAllAccount()
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

    func loadPlaylistOfEntry(entry: Entry) {
        if let url = entry.url {
            self.musicfavClient.playlistify(url).deliverOn(MainScheduler())
                .start(
                    next: { playlist in
                        self.playlistsOfEntry[entry] = playlist
                        self.sink.put(.CompleteLoadingPlaylist(playlist, entry))
                        if let loader = self.loaderOfPlaylist[playlist] {
                            loader.1.dispose()
                        }
                        let loader = PlaylistLoader(playlist: playlist)
                        let disposable = loader.fetchTracks().start(next: { track in
                            }, error: { error in
                            }, completed: {
                        })
                        self.loaderOfPlaylist[playlist] = (loader, disposable)
                    }, error: { error in
                    }, completed: {
                })
        }
    }

    var unreadOnly: Bool {
        if let userId = FeedlyAPIClient.sharedInstance.profile?.id {
            if stream == Tag.Saved(userId) { return false }
            if stream == Tag.Read(userId) {  return false }
        }
        return true
    }

    var removeMark: RemoveMark {
        if let userId = FeedlyAPIClient.sharedInstance.profile?.id {
            if stream == Tag.Saved(userId) { return .Unsave }
            if stream == Tag.Read(userId)  { return .Unread }
        }
        return .Read
    }

    func markAsRead(index: Int) {
        let entry = entries[index]
        if feedlyClient.isLoggedIn {
            feedlyClient.client.markEntriesAsRead([entry.id], completionHandler: { (req, res, error) -> Void in
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
            feedlyClient.client.keepEntriesAsUnread([entry.id], completionHandler: { (req, res, error) -> Void in
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
            feedlyClient.client.markEntriesAsUnsaved([entry.id], completionHandler: { (req, res, error) -> Void in
                if let e = error { println("Failed to mark as unsaved") }
                else             { println("Succeeded in marking as unsaved") }
            })
            feedlyClient.client.markEntriesAsRead([entry.id], completionHandler: { (req, res, error) -> Void in
                if let e = error { println("Failed to mark as read") }
                else             { println("Succeeded in marking as read") }
            })
        }
        entries.removeAtIndex(index)
        sink.put(.RemoveAt(index))
    }
}
