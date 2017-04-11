//
//  StreamTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 1/3/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveSwift
import FeedlyKit
import MusicFeeder
import MBProgressHUD

class StreamTableViewController: AddStreamTableViewController, UISearchBarDelegate {
    enum ListType {
        case search(String)
        case recommend([Feed])
        case hypem(BlogLoader)
    }

    var indicator: UIActivityIndicatorView!

    let client = CloudAPIClient.sharedInstance
    var _streams: [FeedlyKit.Stream]
    var observer: Disposable?
    var disposable: Disposable?

    var streams: [FeedlyKit.Stream] {
        switch type {
        case .recommend:             return _streams
        case .hypem(let blogLoader): return blogLoader.blogs
        case .search:                return _streams
        }
    }

    let streamTableViewCellReuseIdentifier = "StreamTableViewCell"
    var type: ListType

    init(subscriptionRepository: SubscriptionRepository, type: ListType) {
        self.type     = type
        self._streams = []
        super.init(subscriptionRepository: subscriptionRepository)
    }

    required init(coder aDecoder: NSCoder) {
        type     = .recommend([])
        _streams = []
        super.init(coder: aDecoder)
    }

    deinit {}

    func refresh(_ type: ListType) {
        self.type = type
        _streams  = []
        reloadData(false)
        observeBlogs()
        fetchNext()
    }

    override func getSubscribables() -> [FeedlyKit.Stream] {
        if let indexPaths = tableView.indexPathsForSelectedRows {
            return indexPaths.map({
                switch self.type {
                case .recommend:
                    return self.streams[$0.item]
                case .hypem(let blogLoader):
                    return blogLoader.blogs[$0.item]
                case .search:
                    return self.streams[$0.item]
                }
            })
        } else {
            return []
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "StreamTableViewCell", bundle: Bundle.main)
        tableView.register(nib, forCellReuseIdentifier: streamTableViewCellReuseIdentifier)
        navigationItem.title      = "Import Feed".localize()
        indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
        indicator.bounds = CGRect(x: 0,
                                  y: 0,
                              width: indicator.bounds.width,
                             height: indicator.bounds.height * 3)
        indicator.hidesWhenStopped = true
        indicator.stopAnimating()
        refresh(type)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
        switch (type) {
        case .recommend: break
        case .hypem:     observeBlogs()
        case .search:    break
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        observer?.dispose()
        disposable?.dispose()
    }

    func showIndicator() {
        self.tableView.tableFooterView = indicator
        indicator?.startAnimating()
    }

    func hideIndicator() {
        indicator?.stopAnimating()
        self.tableView.tableFooterView = nil
    }

    func fetchNext() {
        switch type {
        case .recommend:
            fetchRecommendFeeds()
        case .hypem(let blogLoader):
            blogLoader.fetchBlogs()
        case .search(let query):
            searchFeeds(query)
        }
    }

    func fetchRecommendFeeds() {
        if let d = disposable {
            if !d.isDisposed { d.dispose() }
        }
        disposable = CloudAPIClient.sharedInstance.fetchFeedsByIds(feedIds: RecommendFeed.ids).on(
            failed: { error in
        }, completed: {
            self.reloadData(true)
        }, value: { feeds in
            self._streams = feeds
        }).start()
    }

    func searchFeeds(_ query: String) {
        if let d = disposable {
            if !d.isDisposed { d.dispose() }
        }
        if query.isEmpty || !_streams.isEmpty { return }
        let query = SearchQueryOfFeed(query: query)
        query.count = 20
        Logger.sendUIActionEvent(self, action: "searchFeeds", label: "")
        disposable = CloudAPIClient.sharedInstance.searchFeeds(query: query)
            .start(on: UIScheduler())
            .on(
                failed: { error in
                    let ac = CloudAPIClient.alertController(error: error, handler: { (action) in })
                    self.present(ac, animated: true, completion: nil)
            },
                completed: {
                    self.reloadData(true)
            },
                value: { feeds in
                    self._streams = feeds
            }).start()
    }

    func observeBlogs() {
        observer?.dispose()
        switch type {
        case .recommend:
            break
        case .hypem(let blogLoader):
            observer = blogLoader.signal.observeResult({ result in
                guard let event = result.value else { return }
                switch event {
                case .startLoading:
                    self.showIndicator()
                case .completeLoading:
                    self.hideIndicator()
                    self.reloadData(true)
                case .failToLoad:
                    self.hideIndicator()
                }
            })
        case .search:
            break
        }
    }

    // MARK: - UIScrollView delegate

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if tableView.contentOffset.y >= tableView.contentSize.height - tableView.bounds.size.height {
            fetchNext()
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return streams.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: streamTableViewCellReuseIdentifier, for: indexPath) as! StreamTableViewCell
        setAccessoryView(cell, indexPath: indexPath)
        switch streams[indexPath.item] {
        case let feed as Feed:
            cell.updateView(feed: feed)
            return cell
        case let blog as Blog:
            cell.updateView(blog: blog)
            return cell
        default:
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.cellHeight
    }
}
