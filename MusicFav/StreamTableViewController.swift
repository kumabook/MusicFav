//
//  StreamTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 1/3/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import LlamaKit
import FeedlyKit

class StreamTableViewController: UITableViewController, UISearchBarDelegate {
    let cellHeight:        CGFloat = 100
    let SEARCH_BAR_HEIGHT: CGFloat = 40
    enum Section: Int {
        case SearchResult = 0
        case Recommend    = 1
        case Hypem        = 2
        static let count  = 3
        var title: String? {
            switch self {
            case .SearchResult:
                return nil
            case .Recommend:
                return "MusicFav Recommend"
            case .Hypem:
                return "Music Blogs (from Hypemachine)"
            }
        }
    }

    var indicator: UIActivityIndicatorView!
    var searchBar: UISearchBar!

    let client = FeedlyAPIClient.sharedInstance
    var searchDisposable: Disposable?
    var isLoggedIn: Bool { return client.account != nil }
    var feeds:            [Feed]
    var recommendFeeds:   [Feed]
    let blogLoader:       BlogLoader
    let streamListLoader: StreamListLoader!
    var observer:         Disposable?

    let streamTableViewCellReuseIdentifier = "StreamTableViewCell"

    init(streamListLoader: StreamListLoader) {
        self.streamListLoader = streamListLoader
        blogLoader            = BlogLoader()
        feeds                 = []
        recommendFeeds        = []
        super.init(nibName: nil, bundle: nil)
    }

    required init(coder aDecoder: NSCoder) {
        streamListLoader = StreamListLoader()
        blogLoader       = BlogLoader()
        feeds            = []
        recommendFeeds   = []
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "StreamTableViewCell", bundle: NSBundle.mainBundle())
        tableView.registerNib(nib, forCellReuseIdentifier: streamTableViewCellReuseIdentifier)
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")

        navigationItem.leftBarButtonItem = UIBarButtonItem(title:"close".localize(),
                                                           style: UIBarButtonItemStyle.Plain,
                                                          target: self,
                                                          action: "close")
        searchBar                 = UISearchBar(frame:CGRectMake(0, 0, view.bounds.size.width, SEARCH_BAR_HEIGHT))
        searchBar.placeholder     = "URL or Keyword".localize()
        searchBar.delegate        = self
        tableView.tableHeaderView = searchBar
        navigationItem.title      = "Import Feed".localize()
        indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
        indicator.bounds = CGRect(x: 0,
                                  y: 0,
                              width: indicator.bounds.width,
                             height: indicator.bounds.height * 3)
        indicator.hidesWhenStopped = true
        indicator.stopAnimating()

        fetchRecommendFeeds()
        observeBlogs()
        fetchBlogs()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        observeBlogs()
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

    func needSearch() -> Bool{
        return searchBar.text != ""
    }

    func searchFeeds(text: String) {
        if searchDisposable != nil && !searchDisposable!.disposed {
            searchDisposable!.dispose()
        }
        feeds = []
        tableView.reloadData()
        if !needSearch() {
            return
        }
        let query = SearchQueryOfFeed(query: text)
        searchDisposable = client.searchFeeds(query)
            .deliverOn(MainScheduler())
            .start(
                next: { feeds in
                    self.feeds = feeds
                },
                error: { error in
                    let ac = FeedlyAPIClient.alertController(error: error, handler: { (action) in })
                    self.presentViewController(ac, animated: true, completion: nil)
                },
                completed: {
                    self.tableView.reloadData()
            })
    }

    func fetchRecommendFeeds() {
        FeedlyAPIClient.sharedInstance.fetchFeedsByIds(RecommendFeed.ids).start(
            next: { feeds in
                self.recommendFeeds = feeds
            }, error: { error in
            }, completed: {
                self.tableView.reloadData()
        })
    }

    func observeBlogs() {
        observer?.dispose()
        observer = blogLoader.hotSignal.observe({ event in
            switch event {
            case .StartLoading:
                self.showIndicator()
            case .CompleteLoading:
                self.hideIndicator()
                self.tableView.reloadData()
            case .FailToLoad:
                self.hideIndicator()
            }
        })
    }

    func fetchBlogs() {
        if !needSearch() { blogLoader.fetchBlogs() }
    }

    // MARK: - UISearchBar delegate

    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        searchFeeds(searchBar.text)
    }

    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        searchFeeds(searchBar.text)
    }

    // MARK: - UIScrollView delegate

    override func scrollViewDidScroll(scrollView: UIScrollView) {
        if tableView.contentOffset.y >= tableView.contentSize.height - tableView.bounds.size.height {
            blogLoader.fetchBlogs()
        }
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return Section.count
    }

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if needSearch() {
            if Section.SearchResult.rawValue == section { return "Search results".localize() }
            else                                        { return nil           }
        } else {
            return Section(rawValue: section)?.title
        }
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (Section(rawValue: section)!) {
        case .SearchResult:
            return feeds.count
        case .Recommend:
            if needSearch() { return 0 }
            return recommendFeeds.count
        case .Hypem:
            if needSearch() { return 0 }
            return blogLoader.blogs.count
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(streamTableViewCellReuseIdentifier, forIndexPath: indexPath) as StreamTableViewCell
        switch Section(rawValue: indexPath.section)! {
        case .SearchResult:
            cell.updateView(feed: feeds[indexPath.item])
            return cell
        case .Recommend:
            cell.updateView(feed: recommendFeeds[indexPath.item])
            return cell
        case .Hypem:
            cell.updateView(blog: blogLoader.blogs[indexPath.item])
            return cell
        }
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var subscribable: Subscribable?
        switch Section(rawValue: indexPath.section)! {
        case .SearchResult:
            subscribable = Subscribable.ToFeed(feeds[indexPath.item])
        case .Recommend:
            subscribable = Subscribable.ToFeed(recommendFeeds[indexPath.item])
        case .Hypem:
            subscribable = Subscribable.ToBlog(blogLoader.blogs[indexPath.item])
        }
        if isLoggedIn {
            if let s = subscribable {
                let ctc = CategoryTableViewController(subscribable: s, streamListLoader: streamListLoader)
                navigationController?.pushViewController(ctc, animated: true)
            }
        }
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section)! {
        case .SearchResult:
            return self.cellHeight
        case .Recommend:
            return self.cellHeight
        case .Hypem:
            return self.cellHeight
        }
    }

    func close() {
        self.navigationController?.dismissViewControllerAnimated(true, nil)
    }
}
