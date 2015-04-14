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

    let client = FeedlyAPIClient.sharedInstance
    var searchDisposable: Disposable?
    var isLoggedIn: Bool { return client.account != nil }
    var feeds:       [Feed]       = []
    var sampleFeeds: [SampleFeed] = SampleFeed.samples()
    var blogLoader                = BlogLoader()

    let streamTableViewCellReuseIdentifier = "StreamTableViewCell"

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "StreamTableViewCell", bundle: NSBundle.mainBundle())
        tableView.registerNib(nib, forCellReuseIdentifier: streamTableViewCellReuseIdentifier)
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")

        navigationItem.leftBarButtonItem = UIBarButtonItem(title:"close".localize(),
                                                           style: UIBarButtonItemStyle.Plain,
                                                          target: self,
                                                          action: "close")
        let searchBar                  = UISearchBar(frame:CGRectMake(0, 0, view.bounds.size.width, SEARCH_BAR_HEIGHT))
        searchBar.placeholder          = "URL or Keyword".localize()
        searchBar.delegate             = self
        self.tableView.tableHeaderView = searchBar
        self.navigationItem.title      = "Import Feed".localize()
        indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
        indicator.bounds = CGRect(x: 0,
            y: 0,
            width: indicator.bounds.width,
            height: indicator.bounds.height * 3)
        indicator.hidesWhenStopped = true
        indicator.stopAnimating()

        observeBlogs()
        fetchBlogs()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func showIndicator() {
        self.tableView.tableFooterView = indicator
        indicator?.startAnimating()
    }

    func hideIndicator() {
        indicator?.stopAnimating()
        self.tableView.tableFooterView = nil
    }

    func searchFeeds(text: String) {
        if searchDisposable != nil && !searchDisposable!.disposed {
            searchDisposable!.dispose()
        }
        feeds = []
        tableView.reloadData()
        if text.lengthOfBytesUsingEncoding(NSStringEncoding.allZeros) == 0 {
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

    func observeBlogs() {
        blogLoader.hotSignal.observe({ event in
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
        blogLoader.fetchBlogs()
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
        return Section(rawValue: section)?.title
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (Section(rawValue: section)!) {
        case .SearchResult:
            return feeds.count
        case .Recommend:
            return sampleFeeds.count
        case .Hypem:
            return blogLoader.blogs.count
        }
    }


    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if let searchResultsTableView = searchDisplayController?.searchResultsTableView {
            if tableView == searchResultsTableView {
                println("search results")
            }
        }
        switch Section(rawValue: indexPath.section)! {
        case .SearchResult:
            let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath) as UITableViewCell
            let feed = feeds[indexPath.item]
            cell.textLabel?.text = "\(feed.title) \(feed.subscribers) " + "subscribers".localize()
            return cell
        case .Recommend:
            let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath) as UITableViewCell
            let feed = sampleFeeds[indexPath.item]
            cell.textLabel?.text = feed.title
            return cell
        case .Hypem:
            let cell = tableView.dequeueReusableCellWithIdentifier(streamTableViewCellReuseIdentifier, forIndexPath: indexPath) as StreamTableViewCell
            cell.updateView(blogLoader.blogs[indexPath.item])
            return cell
        }
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .SearchResult:
            let feed = feeds[indexPath.item]
            if isLoggedIn {
                let ctc = CategoryTableViewController()
                ctc.feed = feed
                navigationController?.pushViewController(ctc, animated: true)
            }
        case .Recommend:
            break
        case .Hypem:
            break
        }
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section)! {
        case .SearchResult:
            return super.tableView(tableView, heightForRowAtIndexPath: indexPath)
        case .Recommend:
            return super.tableView(tableView, heightForRowAtIndexPath: indexPath)
        case .Hypem:
            return self.cellHeight
        }
    }

    func close() {
        self.navigationController?.dismissViewControllerAnimated(true, nil)
    }
}
