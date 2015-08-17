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
        case Recommend
        case Hypem
        var title: String? {
            switch self {
            case .Recommend:    return "MusicFav Recommend"
            case .Hypem:        return "Music Blogs (from Hypemachine)"
            }
        }
    }

    var indicator: UIActivityIndicatorView!

    let client = CloudAPIClient.sharedInstance
    var recommendFeeds:   [Feed]
    let blogLoader:       BlogLoader
    var observer:         Disposable?

    let streamTableViewCellReuseIdentifier = "StreamTableViewCell"
    let type: Type

    init(streamListLoader: StreamListLoader, type: Type, blogLoader: BlogLoader, recommendFeeds: [Feed]) {
        self.type             = type
        self.blogLoader       = blogLoader
        self.recommendFeeds   = recommendFeeds
        super.init(streamListLoader: streamListLoader)
    }

    required init(coder aDecoder: NSCoder) {
        type             = .Recommend
        blogLoader       = BlogLoader()
        recommendFeeds   = []
        super.init(coder: aDecoder)
    }

    deinit {}

    override func getSubscribables() -> [Stream] {
        if let indexPaths = tableView.indexPathsForSelectedRows() {
            return indexPaths.map({
                switch self.type {
                case .Recommend:
                    return self.recommendFeeds[$0.item]
                case .Hypem:
                    return self.blogLoader.blogs[$0.item]
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
        switch (type) {
            case .Recommend:
                fetchRecommendFeeds()
            case .Hypem:
                observeBlogs()
                fetchBlogs()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
        switch (type) {
        case .Recommend:    break
        case .Hypem:        observeBlogs()
        }
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        observer?.dispose()
    }

    func showIndicator() {
        self.tableView.tableFooterView = indicator
        indicator?.startAnimating()
    }

    func hideIndicator() {
        indicator?.stopAnimating()
        self.tableView.tableFooterView = nil
    }

    func fetchRecommendFeeds() {
        CloudAPIClient.sharedInstance.fetchFeedsByIds(RecommendFeed.ids).start(
            next: { feeds in
                self.recommendFeeds = feeds
            }, error: { error in
            }, completed: {
                self.reloadData(keepSelection: true)
        })
    }

    func observeBlogs() {
        observer?.dispose()
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
    }

    func fetchBlogs() {
        blogLoader.fetchBlogs()
    }

    // MARK: - UIScrollView delegate

    override func scrollViewDidScroll(scrollView: UIScrollView) {
        if tableView.contentOffset.y >= tableView.contentSize.height - tableView.bounds.size.height {
            blogLoader.fetchBlogs()
        }
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return type.title
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (type) {
        case .Recommend:
            return recommendFeeds.count
        case .Hypem:
            return blogLoader.blogs.count
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(streamTableViewCellReuseIdentifier, forIndexPath: indexPath) as! StreamTableViewCell
        setAccessoryView(cell, indexPath: indexPath)
        switch type {
        case .Recommend:
            cell.updateView(feed: recommendFeeds[indexPath.item])
            return cell
        case .Hypem:
            cell.updateView(blog: blogLoader.blogs[indexPath.item])
            return cell
        }
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return self.cellHeight
    }
}
