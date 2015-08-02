//
//  AddStreamTableViewController.swift
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

class AddStreamTableViewController: UITableViewController, UISearchBarDelegate {
    let cellHeight:        CGFloat = 100
    let accessoryWidth:    CGFloat = 30
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

    let client = CloudAPIClient.sharedInstance
    var searchDisposable: Disposable?
    var isLoggedIn: Bool { return FeedlyAPI.account != nil }
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

    deinit {}

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "StreamTableViewCell", bundle: NSBundle.mainBundle())
        tableView.registerNib(nib, forCellReuseIdentifier: streamTableViewCellReuseIdentifier)
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")

        navigationItem.leftBarButtonItem = UIBarButtonItem(title:"Close".localize(),
                                                           style: UIBarButtonItemStyle.Plain,
                                                          target: self,
                                                          action: "close")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title:"Add".localize(),
                                                           style: UIBarButtonItemStyle.Plain,
                                                          target: self,
                                                          action: "add")
        navigationItem.rightBarButtonItem?.enabled = false

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

        tableView.allowsMultipleSelection = true
        fetchRecommendFeeds()
        observeBlogs()
        fetchBlogs()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
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
        Logger.sendUIActionEvent(self, action: "searchFeeds", label: "")
        if searchDisposable != nil && !searchDisposable!.disposed {
            searchDisposable!.dispose()
        }
        feeds = []
        reloadData(keepSelection: false)
        if !needSearch() {
            return
        }
        let query = SearchQueryOfFeed(query: text)
        searchDisposable = client.searchFeeds(query)
            |> startOn(UIScheduler())
            |> start(
                next: { feeds in
                    self.feeds = feeds
                },
                error: { error in
                    let ac = CloudAPIClient.alertController(error: error, handler: { (action) in })
                    self.presentViewController(ac, animated: true, completion: nil)
                },
                completed: {
                    self.reloadData(keepSelection: false)
            })
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
        if !needSearch() { blogLoader.fetchBlogs() }
    }

    func reloadData(#keepSelection: Bool) {
        let indexPaths = tableView.indexPathsForSelectedRows()
        tableView.reloadData()
        if keepSelection, let indexes = indexPaths as? [NSIndexPath] {
            for index in indexes {
                tableView.selectRowAtIndexPath(index, animated: false, scrollPosition: UITableViewScrollPosition.None)
            }
        }
    }

    func isSelected(#indexPath: NSIndexPath) -> Bool {
        if let indexPaths = tableView.indexPathsForSelectedRows() as? [NSIndexPath] {
            return contains(indexPaths, { $0 == indexPath})
        }
        return false
    }

    func setAccessoryView(cell: UITableViewCell, indexPath: NSIndexPath) {
        if isSelected(indexPath: indexPath) {
            var image             = UIImage(named: "checkmark")
            image                 = image!.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
            let imageView         = UIImageView(image: image)
            imageView.frame       = CGRect(x: 0, y: 0, width: accessoryWidth, height: cellHeight)
            imageView.contentMode = UIViewContentMode.ScaleAspectFit
            imageView.tintColor   = UIColor.theme
            cell.accessoryView    = imageView
        } else {
            cell.accessoryView = UIView(frame: CGRect(x: 0, y: 0, width: accessoryWidth, height: cellHeight))
        }
    }

    func updateAddButton() {
        if let count = tableView.indexPathsForSelectedRows()?.count {
            navigationItem.rightBarButtonItem?.enabled = count > 0
        } else {
            navigationItem.rightBarButtonItem?.enabled = false
        }
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
        let cell = tableView.dequeueReusableCellWithIdentifier(streamTableViewCellReuseIdentifier, forIndexPath: indexPath) as! StreamTableViewCell
        setAccessoryView(cell, indexPath: indexPath)
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
        if let cell = tableView.cellForRowAtIndexPath(indexPath) {
            setAccessoryView(cell, indexPath: indexPath)
        }
        updateAddButton()
    }

    override func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        if let cell = tableView.cellForRowAtIndexPath(indexPath) {
            setAccessoryView(cell, indexPath: indexPath)
        }
        updateAddButton()
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
        self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }

    func add() {
        if let indexPaths = tableView.indexPathsForSelectedRows() {
            let subscribables: [Subscribable] = indexPaths.map({
                switch Section(rawValue: $0.section)! {
                case .SearchResult:
                    return SubscribableFeed(feed: self.feeds[$0.item])
                case .Recommend:
                    return SubscribableFeed(feed: self.recommendFeeds[$0.item])
                case .Hypem:
                    return self.blogLoader.blogs[$0.item]
                }
            })
            Logger.sendUIActionEvent(self, action: "add", label: "")
            if isLoggedIn {
                let ctc = CategoryTableViewController(subscribables: subscribables, streamListLoader: streamListLoader)
                navigationController?.pushViewController(ctc, animated: true)
            } else {
                MBProgressHUD.showHUDAddedTo(self.navigationController!.view, animated: true)
                subscribables.reduce(SignalProducer<[Subscription], NSError>(value: [])) {
                    combineLatest($0, self.streamListLoader.subscribeTo($1, categories: [])) |> map {
                        var list = $0.0; list.append($0.1); return list
                    }
                } |> start(
                    next: { subscriptions in
                        MBProgressHUD.hideHUDForView(self.navigationController!.view, animated:false)
                    }, error: { e in
                        MBProgressHUD.hideHUDForView(self.navigationController!.view, animated:false)
                        let ac = CloudAPIClient.alertController(error: e, handler: { (action) in })
                    }, completed: {
                        MBProgressHUD.showCompletedHUDForView(self.navigationController!.view, animated: true, duration: 1.0, after: {
                            self.streamListLoader.refresh()
                            self.navigationController?.dismissViewControllerAnimated(true, completion: {})
                        })
                })
            }
        }
    }
}
