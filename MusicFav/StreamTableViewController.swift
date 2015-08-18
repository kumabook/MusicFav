//
//  StreamTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 1/3/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import FeedlyKit
import MusicFeeder
import MBProgressHUD

class StreamTableViewController: AddStreamTableViewController, UISearchBarDelegate {
    enum Type {
        case Search(String)
        case Recommend([Feed])
        case Hypem(BlogLoader)
    }

    var indicator: UIActivityIndicatorView!

    let client = CloudAPIClient.sharedInstance
    var _streams: [Stream]
    var observer: Disposable?
    var disposable: Disposable?

    var streams: [Stream] {
        switch type {
        case .Recommend:             return _streams
        case .Hypem(let blogLoader): return blogLoader.blogs
        case .Search(let query):     return _streams
        }
    }

    let streamTableViewCellReuseIdentifier = "StreamTableViewCell"
    var type: Type

    init(streamListLoader: StreamListLoader, type: Type) {
        self.type     = type
        self._streams = []
        super.init(streamListLoader: streamListLoader)
    }

    required init(coder aDecoder: NSCoder) {
        type     = .Recommend([])
        _streams = []
        super.init(coder: aDecoder)
    }

    deinit {}

    func refresh(type: Type) {
        self.type = type
        _streams  = []
        reloadData(keepSelection: false)
        observeBlogs()
        fetchNext()
    }

    override func getSubscribables() -> [Stream] {
        if let indexPaths = tableView.indexPathsForSelectedRows() {
            return indexPaths.map({
                switch self.type {
                case .Recommend:
                    return self.streams[$0.item]
                case .Hypem(let blogLoader):
                    return blogLoader.blogs[$0.item]
                case .Search(let query):
                    return self.streams[$0.item]
                }
            })
        } else {
            return []
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "StreamTableViewCell", bundle: NSBundle.mainBundle())
        tableView.registerNib(nib, forCellReuseIdentifier: streamTableViewCellReuseIdentifier)
        navigationItem.title      = "Import Feed".localize()
        indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
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

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
        switch (type) {
        case .Recommend: break
        case .Hypem:     observeBlogs()
        case .Search:    break
        }
    }

    override func viewDidDisappear(animated: Bool) {
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
        case .Recommend:
            fetchRecommendFeeds()
        case .Hypem(let blogLoader):
            blogLoader.fetchBlogs()
        case .Search(let query):
            searchFeeds(query)
        }
    }

    func fetchRecommendFeeds() {
        if let d = disposable {
            if !d.disposed { d.dispose() }
        }
        disposable = CloudAPIClient.sharedInstance.fetchFeedsByIds(RecommendFeed.ids).start(
            next: { feeds in
                self._streams = feeds
            }, error: { error in
            }, completed: {
                self.reloadData(keepSelection: true)
        })
    }

    func searchFeeds(query: String) {
        if let d = disposable {
            if !d.disposed { d.dispose() }
        }
        if query.isEmpty || !_streams.isEmpty { return }
        let query = SearchQueryOfFeed(query: query)
        query.count = 20
        Logger.sendUIActionEvent(self, action: "searchFeeds", label: "")
        disposable = CloudAPIClient.sharedInstance.searchFeeds(query)
            |> startOn(UIScheduler())
            |> start(
                next: { feeds in
                    self._streams = feeds
                },
                error: { error in
                    let ac = CloudAPIClient.alertController(error: error, handler: { (action) in })
                    self.presentViewController(ac, animated: true, completion: nil)
                },
                completed: {
                    self.reloadData(keepSelection: true)
            })
    }

    func observeBlogs() {
        observer?.dispose()
        switch type {
        case .Recommend:
            break
        case .Hypem(let blogLoader):
            observer = blogLoader.signal.observe(next: { event in
                switch event {
                case .StartLoading:
                    self.showIndicator()
                case .CompleteLoading:
                    self.hideIndicator()
                    self.reloadData(keepSelection: true)
                case .FailToLoad:
                    self.hideIndicator()
                }
            })
        case .Search(let query):
            break
        }
    }

    // MARK: - UIScrollView delegate

    override func scrollViewDidScroll(scrollView: UIScrollView) {
        if tableView.contentOffset.y >= tableView.contentSize.height - tableView.bounds.size.height {
            fetchNext()
        }
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return streams.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(streamTableViewCellReuseIdentifier, forIndexPath: indexPath) as! StreamTableViewCell
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

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return self.cellHeight
    }
}
