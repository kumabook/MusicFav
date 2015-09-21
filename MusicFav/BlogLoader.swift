//
//  BlogLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/13/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import ReactiveCocoa
import Result
import FeedlyKit

public class BlogLoader {
    public enum State {
        case Init
        case FetchingAllBlogs
        case Normal
        case FetchingDetails
        case Complete
        case Error
    }

    public enum Event {
        case StartLoading
        case CompleteLoading
        case FailToLoad
    }

    private var _blogs: [Blog]
    public var blogs:          [Blog]
    var offset  = 0
    var perPage = 5
    public var state:          State
    public var signal:         Signal<Event, NSError>
    public var sink:           Signal<Event, NSError>.Observer

    public init() {
        self._blogs = []
        self.blogs  = []
        self.state  = .Init
        let pipe    = Signal<Event, NSError>.pipe()
        signal      = pipe.0
        sink        = pipe.1
    }

    private func fetchAllBlogs() -> SignalProducer<Void, NSError> {
        state = State.FetchingAllBlogs
        sink(ReactiveCocoa.Event<Event, NSError>.Next(.StartLoading))
        return HypemAPIClient.sharedInstance.getAllBlogs().map {
            self._blogs = $0
            self.fetchNextDetails()
            return
        }
    }

    public func fetchBlogs() {
        switch state {
        case .Init:             fetchAllBlogs().on(next: {}, error: {e in}, completed: {}).start()
        case .FetchingAllBlogs: break
        case .Normal:           fetchNextDetails()
        case .FetchingDetails:  break
        case .Complete:         break
        case .Error:            break
        }
    }

    private func fetchNextDetails() {
        self.state  = State.FetchingDetails
        sink(.Next(.StartLoading))
        fetchDetails(start: offset, length: perPage).on(
            next: { blog in
                self.offset += self.perPage
                self.sink(.Next(.CompleteLoading))
            }, error: { error in
                self.sink(.Next(.FailToLoad))
            }, completed: {
                if self.offset >= self._blogs.count {
                    self.state = .Complete
                } else {
                    self.state = .Normal
                }
                return
        }).start()
    }

    private func fetchDetails(start start: Int, length: Int) -> SignalProducer<[Blog], NSError> {
        return (start..<start+length).map({$0}).reduce(SignalProducer(value: [])) {
            combineLatest($0, self.fetchSiteInfo($1)).map {
                var list = $0.0; list.append($0.1); return list
            }
        }
    }

    private func fetchSiteInfo(index: Int) -> SignalProducer<Blog, NSError> {
        return SignalProducer<Blog, NSError> { (blogSink, disposable) in
            self._blogs[index].fetchSiteInfo().on(
                next: { blog in
                    self.blogs.append(blog)
                    blogSink(.Next(blog))
                    blogSink(.Completed)
                },
                error: { error in
                    blogSink(.Error(error))
                    return
                },
                completed: {
            }).start()
            return
        }
    }
}