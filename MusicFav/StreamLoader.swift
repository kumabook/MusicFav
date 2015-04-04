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

class SampleFeed: Stream {
    let id:    String
    let title: String
    override var streamId:    String { return id }
    override var streamTitle: String { return title }
    init(id: String, title: String) {
        self.id    = id
        self.title = title
        super.init()
    }
}

class StreamLoader {
    class func defaultStream() -> Stream {
        if let profile = FeedlyAPIClient.sharedInstance._profile {
            return FeedlyKit.Category.All(profile.id)
        } else {
            let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
            let sampleFeeds  = appDelegate.sampleFeeds
            return SampleFeed(id: sampleFeeds[0], title: "Sample feeds")
        }
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
    }

    let unreadOnly: Bool
    let feedlyClient     = FeedlyAPIClient.sharedInstance
    let musicfavClient   = MusicFavAPIClient.sharedInstance

    let stream:             Stream
    var lastUpdated:        Int64
    var state:              State
    var entries:            [Entry]
    var playlistsOfEntry:   [Entry:Playlist]
    var streamContinuation: String?
    var hotSignal:          HotSignal<Event>
    var sink:               SinkOf<Event>

    init(stream: Stream, unreadOnly: Bool) {
        self.stream      = stream
        self.unreadOnly  = unreadOnly
        state            = .Normal
        lastUpdated      = 0
        entries          = []
        playlistsOfEntry = [:]
        let pipe = HotSignal<Event>.pipe()
        hotSignal        = pipe.0
        sink             = pipe.1
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
                    if paginatedCollection.continuation == nil {
                        self.state = .Complete
                    } else {
                        self.state = .Normal
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
                    self.sink.put(.CompleteLoadingNext)
            })
    }

    func loadPlaylistOfEntry(entry: Entry) {
        if let url = entry.url {
            self.musicfavClient.playlistify(url).deliverOn(MainScheduler())
                .start(
                    next: { playlist in
                        self.playlistsOfEntry[entry] = playlist
                        self.sink.put(.CompleteLoadingPlaylist(playlist, entry))
                    }, error: { error in
                    }, completed: {
                })
        }
    }
}
