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
    var offset = 0
    var perPage = 5
    var state:          State
    var hotSignal:      HotSignal<Event>
    var sink:           SinkOf<Event>

    init() {
        self._blogs = []
        self.blogs  = []
        self.state = .Init
        let pipe   = HotSignal<Event>.pipe()
        hotSignal  = pipe.0
        sink       = pipe.1
    }

    private func fetchAllBlogs() -> ColdSignal<Void> {
        state = State.FetchingAllBlogs
        sink.put(.StartLoading)
        return HypemAPIClient.sharedInstance.getAllBlogs().map({
            self._blogs = $0
            self.fetchNextDetails()
            return
        })
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
        sink.put(.StartLoading)
        fetchDetails(start: offset, length: perPage).start(
            next: { blog in
                self.offset += self.perPage
                self.sink.put(.CompleteLoading)
            }, error: { error in
                self.sink.put(.FailToLoad)
            }, completed: {
                if self.offset >= self._blogs.count {
                    self.state = .Complete
                } else {
                    self.state = .Normal
                }
                return
        })
    }

    private func fetchDetails(#start: Int, length: Int) -> ColdSignal<[Blog]> {
        var signal = ColdSignal<Blog>.empty()
        for i in start..<start+length {
            signal = signal.concat(fetchDetail(i))
        }
        return signal.reduce(initial: [], {var list = $0; list.append($1); return list})
    }

    private func fetchDetail(index: Int) -> ColdSignal<Blog> {
        return ColdSignal<Blog> { (coldSink, disposable) in
            self._blogs[index].fetchDetail().start(
                next: { blog in
                    self._blogs[index] = blog
                    self.blogs.append(blog)
                    coldSink.put(.Next(Box(blog)))
                    coldSink.put(.Completed)
                },
                error: { error in
                    coldSink.put(.Error(error))
                    return
                },
                completed: {
            })
            return
        }
    }
}