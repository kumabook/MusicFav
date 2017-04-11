//
//  BlogLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/13/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import ReactiveSwift
import Result
import FeedlyKit

open class BlogLoader {
    public enum State {
        case `init`
        case fetchingAllBlogs
        case normal
        case fetchingDetails
        case complete
        case error
    }

    public enum Event {
        case startLoading
        case completeLoading
        case failToLoad
    }

    fileprivate var _blogs: [Blog]
    open var blogs:          [Blog]
    var offset  = 0
    var perPage = 5
    open var state:          State
    open var signal:         Signal<Event, NSError>
    open var observer:       Signal<Event, NSError>.Observer

    public init() {
        self._blogs = []
        self.blogs  = []
        self.state  = .init
        let pipe    = Signal<Event, NSError>.pipe()
        signal      = pipe.0
        observer    = pipe.1
    }

    fileprivate func fetchAllBlogs() -> SignalProducer<Void, NSError> {
        state = State.fetchingAllBlogs
        observer.send(value: .startLoading)
        return HypemAPIClient.sharedInstance.getAllBlogs().map {
            self._blogs = $0
            self.fetchNextDetails()
            return
        }
    }

    open func fetchBlogs() {
        switch state {
        case .init:             fetchAllBlogs().on(failed: {e in}, completed: {}, value: {}).start()
        case .fetchingAllBlogs: break
        case .normal:           fetchNextDetails()
        case .fetchingDetails:  break
        case .complete:         break
        case .error:            break
        }
    }

    fileprivate func fetchNextDetails() {
        self.state  = State.fetchingDetails
        observer.send(value: .startLoading)
        fetchDetails(offset, length: perPage).on(
            failed: { error in
                self.observer.send(value: .failToLoad)
        }, completed: {
            if self.offset >= self._blogs.count {
                self.state = .complete
            } else {
                self.state = .normal
            }
            return
        }, value: { blog in
            self.offset += self.perPage
            self.observer.send(value: .completeLoading)
        }).start()
    }

    fileprivate func fetchDetails(_ start: Int, length: Int) -> SignalProducer<[Blog], NSError> {
        return (start..<start+length).map({$0}).reduce(SignalProducer(value: [])) {
            SignalProducer.combineLatest($0, self.fetchSiteInfo($1)).map {
                var list = $0.0; list.append($0.1); return list
            }
        }
    }

    fileprivate func fetchSiteInfo(_ index: Int) -> SignalProducer<Blog, NSError> {
        return SignalProducer<Blog, NSError> { (blogObserver, disposable) in
            self._blogs[index].fetchSiteInfo().on(
                failed: { error in
                    blogObserver.send(error: error)
                    return
            },
                completed: {
            },
                value: { blog in
                    self.blogs.append(blog)
                    blogObserver.send(value: blog)
                    blogObserver.sendCompleted()
            }).start()
            return
        }
    }
}
