//
//  StreamLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/4/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import FeedlyKit
import ReactiveCocoa
import Result
import Box

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
    var signal:             Signal<Event, NSError>
    var sink:               SinkOf<ReactiveCocoa.Event<Event, NSError>>

    init(stream: Stream) {
        self.stream      = stream
        state            = .Normal
        lastUpdated      = 0
        entries          = []
        playlistsOfEntry = [:]
        loaderOfPlaylist = [:]
        let pipe         = Signal<Event, NSError>.pipe()
        signal           = pipe.0
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

    var playlists: [Playlist] {
        return entries.map { self.playlistsOfEntry[$0] }
                      .filter { $0 != nil && $0!.validTracksCount > 0 }
                      .map { $0! }
    }

    func fetchLatestEntries() {
        if entries.count == 0 {
            return
        }

        var producer: SignalProducer<PaginatedEntryCollection, NSError>
        producer = feedlyClient.fetchEntries(streamId: stream.streamId,
                                          newerThan: lastUpdated,
                                         unreadOnly: unreadOnly)
        sink.put(.Next(Box(.StartLoadingLatest)))
        producer |> startOn(UIScheduler())
               |> start(
                next: { paginatedCollection in
                    var latestEntries = paginatedCollection.items
                    self.playlistifier = latestEntries.map({
                        self.loadPlaylistOfEntry($0)
                    }).reduce(SignalProducer<Void, NSError>.empty, combine: { (currentSignal, nextSignal) in
                        currentSignal |> concat(nextSignal)
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
                    self.sink.put(.Next(Box(.CompleteLoadingLatest)))
            })
    }

    func fetchEntries() {
        if state != .Normal {
            return
        }
        state = .Fetching
        sink.put(.Next(Box(.StartLoadingNext)))
        var producer: SignalProducer<PaginatedEntryCollection, NSError>
        producer = feedlyClient.fetchEntries(streamId:stream.streamId, continuation: streamContinuation, unreadOnly: unreadOnly)
        producer |> startOn(UIScheduler())
               |> start(
                next: {paginatedCollection in
                    let entries = paginatedCollection.items
                    self.entries.extend(entries)
                    self.playlistifier = entries.map({
                        self.loadPlaylistOfEntry($0)
                    }).reduce(SignalProducer<Void, NSError>.empty, combine: { (currentSignal, nextSignal) in
                        currentSignal |> concat(nextSignal)
                    }) |> start(next: {}, error: {error in}, completed: {})
                    self.streamContinuation = paginatedCollection.continuation
                    self.updateLastUpdated(paginatedCollection.updated)
                    self.sink.put(.Next(Box(.CompleteLoadingNext))) // First reload tableView,
                    if paginatedCollection.continuation == nil {    // then wait for next load
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
                                self.sink.put(.Next(Box(.FailToLoadNext)))
                            }
                        } else {
                            self.state = State.Error
                            self.sink.put(.Next(Box(.FailToLoadNext)))
                        }
                    }
                },
                completed: {
            })
    }

    func loadPlaylistOfEntry(entry: Entry) -> SignalProducer<Void, NSError> {
        if let url = entry.url {
            return musicfavClient.playlistify(url, errorOnFailure: false) |> map({ playlist in
                self.playlistsOfEntry[entry] = playlist
                UIScheduler().schedule {
                    self.sink.put(.Next(Box(.CompleteLoadingPlaylist(playlist, entry))))
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
        return SignalProducer<Void, NSError>.empty
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
        sink.put(.Next(Box(.RemoveAt(index))))
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
        sink.put(.Next(Box(.RemoveAt(index))))
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
        sink.put(.Next(Box(.RemoveAt(index))))
    }
}
