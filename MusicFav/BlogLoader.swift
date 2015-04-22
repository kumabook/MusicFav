//
//  BlogLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/13/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import ReactiveCocoa
import LlamaKit
import FeedlyKit

class BlogLoader {
    enum State {
        case Init
        case FetchingAllBlogs
        case Normal
        case FetchingDetails
        case Complete
        case Error
    }

    enum Event {
        case StartLoading
        case CompleteLoading
        case FailToLoad
    }

    private var _blogs: [Blog]
    var blogs:          [Blog]
    var offset  = 0
    var perPage = 5
    var state:          State
    var signal:         Signal<Event, NSError>
    var sink:           SinkOf<ReactiveCocoa.Event<Event, NSError>>

    init() {
        self._blogs = []
        self.blogs  = []
        self.state  = .Init
        let pipe    = Signal<Event, NSError>.pipe()
        signal      = pipe.0
        sink        = pipe.1
    }

    private func fetchAllBlogs() -> SignalProducer<Void, NSError> {
        state = State.FetchingAllBlogs
        sink.put(ReactiveCocoa.Event<Event, NSError>.Next(Box(.StartLoading)))
        return HypemAPIClient.sharedInstance.getAllBlogs() |> map {
            self._blogs = $0
            self.fetchNextDetails()
            return
        }
    }

    func fetchBlogs() {
        switch state {
        case .Init:             fetchAllBlogs().start(next: {}, error: {e in}, completed: {})
        case .FetchingAllBlogs: break
        case .Normal:           fetchNextDetails()
        case .FetchingDetails:  break
        case .Complete:         break
        case .Error:            break
        }
    }

    private func fetchNextDetails() {
        self.state  = State.FetchingDetails
        sink.put(.Next(Box(.StartLoading)))
        fetchDetails(start: offset, length: perPage).start(
            next: { blog in
                self.offset += self.perPage
                self.sink.put(.Next(Box(.CompleteLoading)))
            }, error: { error in
                self.sink.put(.Next(Box(.FailToLoad)))
            }, completed: {
                if self.offset >= self._blogs.count {
                    self.state = .Complete
                } else {
                    self.state = .Normal
                }
                return
        })
    }

    private func fetchDetails(#start: Int, length: Int) -> SignalProducer<[Blog], NSError> {
        var producer = SignalProducer<Blog, NSError>.empty
        for i in start..<start+length {
            producer = producer |> concat(fetchSiteInfo(i))
        }
        return producer |> reduce([], {var list = $0; list.append($1); return list})
    }

    private func fetchSiteInfo(index: Int) -> SignalProducer<Blog, NSError> {
        return SignalProducer<Blog, NSError> { (blogSink, disposable) in
            self._blogs[index].fetchSiteInfo().start(
                next: { blog in
                    self.blogs.append(blog)
                    blogSink.put(.Next(Box(blog)))
                    blogSink.put(.Completed)
                },
                error: { error in
                    blogSink.put(.Error(Box(error)))
                    return
                },
                completed: {
            })
            return
        }
    }
}