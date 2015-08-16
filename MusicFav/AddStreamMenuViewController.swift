//
//  AddStreamMenuViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/1/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import MusicFeeder
import FeedlyKit

class AddStreamMenuViewController: UITableViewController, UISearchBarDelegate {
    let reuseIdentifier = "reuseIdentifier"
    let cellHeight:        CGFloat = 120
    let accessoryWidth:    CGFloat = 30
    let SEARCH_BAR_HEIGHT: CGFloat = 40
    enum Menu: Int {
        case Recommend
        case YouTube
        case Hypem
        static let count = 3
        var title: String? {
            switch self {
            case .Recommend:
                return "MusicFav Recommend"
            case .YouTube:
                return "YouTube"
            case .Hypem:
                return "Hype machine featured"
            }
        }
    }

    var indicator: UIActivityIndicatorView!
    var searchBar: UISearchBar!

    var streamListLoader: StreamListLoader!
    var recommendFeeds:   [Feed]
    let blogLoader:       BlogLoader
    var blogObserver:     Disposable?
    var channelLoader:    ChannelLoader!
    var channelObserver:  Disposable?

    init(streamListLoader: StreamListLoader) {
        self.streamListLoader = streamListLoader
        self.blogLoader       = BlogLoader()
        self.channelLoader    = ChannelLoader()
        self.recommendFeeds   = []
        super.init(nibName: nil, bundle: nil)
    }

    required init(coder aDecoder: NSCoder) {
        streamListLoader = StreamListLoader()
        blogLoader       = BlogLoader()
        channelLoader    = ChannelLoader()
        recommendFeeds   = []
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView?.registerNib(UINib(nibName: "AddStreamMenuTableViewCell", bundle: nil) , forCellReuseIdentifier: reuseIdentifier)
        navigationItem.leftBarButtonItem = UIBarButtonItem(title:"Close".localize(),
                                                           style: UIBarButtonItemStyle.Plain,
                                                          target: self,
                                                          action: "close")
        navigationItem.rightBarButtonItem?.enabled = false
        searchBar                 = UISearchBar(frame:CGRectMake(0, 0, view.bounds.size.width, SEARCH_BAR_HEIGHT))
        searchBar.placeholder     = "URL or Keyword".localize()
        searchBar.delegate        = self
        tableView.tableHeaderView = searchBar
        navigationItem.title      = "Import Feed".localize()

        observeBlogLoader()
        observeChannelLoader()
        fetchRecommendFeeds()
        fetchBlogs()
        if YouTubeAPIClient.isLoggedIn {
            channelLoader.fetchSubscriptions()
        } else {
            channelLoader.searchChannelsByMusic()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func close() {
        dismissViewControllerAnimated(true, completion: {})
    }

    func fetchRecommendFeeds() {
        CloudAPIClient.sharedInstance.fetchFeedsByIds(RecommendFeed.ids).start(
            next: { feeds in
                self.recommendFeeds = feeds
            }, error: { error in
            }, completed: {
                self.tableView?.reloadData()
        })
    }

    func observeBlogLoader() {
        blogObserver?.dispose()
        blogObserver = blogLoader.signal.observe(next: { event in
            switch event {
            case .StartLoading:    break
            case .CompleteLoading: self.tableView?.reloadData()
            case .FailToLoad:      break
            }
        })
    }

    func observeChannelLoader() {
        channelObserver?.dispose()
        channelObserver = channelLoader.signal.observe(next: { event in
            switch event {
            case .StartLoading: break
            case .CompleteLoading:
                self.tableView.reloadData()
            case .FailToLoad: break
            }
        })
    }

    func fetchBlogs() {
        blogLoader.fetchBlogs()
    }

    // MARK: - UISearchBarDelegate

    func searchBarShouldBeginEditing(searchBar: UISearchBar) -> Bool {
        let vc = SearchStreamViewController(streamListLoader: streamListLoader)
        vc.modalTransitionStyle = UIModalTransitionStyle.FlipHorizontal
        presentViewController(UINavigationController(rootViewController: vc), animated: true, completion: {})
        return false
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Menu.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath: indexPath) as! AddStreamMenuTableViewCell
        if let menu = Menu(rawValue: indexPath.item) {
            switch menu {
            case .Recommend:
                cell.nameLabel?.text = "MusicFav Recommend"
                cell.setThumbnailImages(recommendFeeds.flatMap { $0.thumbnailURL.map { [$0] } ?? [] })
            case .YouTube:
                cell.nameLabel?.text = "YouTube"
                var urls: [NSURL]
                if YouTubeAPIClient.isLoggedIn {
                    urls = channelLoader.subscriptions.flatMap { $0.thumbnailURL.map { [$0] } ?? [] }
                } else {
                    urls = channelLoader.channels.flatMap { $0.thumbnailURL.map { [$0] } ?? [] }
                }
                if urls.count > 0 {
                    cell.setThumbnailImages(urls)
                } else {
                    cell.setMessageLabel("")
                }
            case .Hypem:
                cell.nameLabel?.text = "Hype machine featured"
                cell.setThumbnailImages(blogLoader.blogs.flatMap { $0.thumbnailURL.map { [$0] } ?? [] })
            }
        }
        return cell
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let menu = Menu(rawValue: indexPath.item) {
            switch menu {
            case .Recommend:
                let vc = StreamTableViewController(streamListLoader: streamListLoader,
                                                                  type: .Recommend,
                                                            blogLoader: blogLoader,
                                                        recommendFeeds: recommendFeeds)
                navigationController?.pushViewController(vc, animated: true)
            case .YouTube:
                let vc = ChannelCategoryTableViewController(streamListLoader: streamListLoader, channelLoader: channelLoader)
                navigationController?.pushViewController(vc, animated: true)
                vc.showYouTubeLoginViewController()
            case .Hypem:
                let vc = StreamTableViewController(streamListLoader: streamListLoader,
                                                                  type: .Hypem,
                                                            blogLoader: blogLoader,
                                                        recommendFeeds: recommendFeeds)
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return cellHeight
    }
}
