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
import SoundCloudKit

class AddStreamMenuViewController: UITableViewController, UISearchBarDelegate {
    let reuseIdentifier = "reuseIdentifier"
    let cellHeight:        CGFloat = 120
    let accessoryWidth:    CGFloat = 30
    let SEARCH_BAR_HEIGHT: CGFloat = 40
    enum Menu: Int {
        case Recommend
        case YouTube
        case Hypem
        case SoundCloud
        static let count = 3
        var title: String? {
            switch self {
            case .Recommend:
                return "MusicFav Recommend".localize()
            case .YouTube:
                return "YouTube"
            case .SoundCloud:
                return "SoundCloud"
            case .Hypem:
                return "Hype machine featured".localize()
            }
        }
        func thumbnailUrls(vc: AddStreamMenuViewController) -> [NSURL] {
            switch self {
            case .Recommend:
                return vc.recommendFeeds.flatMap { $0.thumbnailURL.map { [$0] } ?? [] }
            case .YouTube:
                if YouTubeAPIClient.isLoggedIn {
                    return vc.channelLoader.subscriptions.flatMap { $0.thumbnailURL.map { [$0] } ?? [] }
                } else {
                    return vc.channelLoader.searchResults.flatMap { $0.thumbnailURL.map { [$0] } ?? [] }
                }
            case .SoundCloud:
                if SoundCloudKit.APIClient.isLoggedIn {
                    return vc.userLoader.followings.flatMap { $0.thumbnailURL.map { [$0] } ?? [] }
                } else {
                    return vc.userLoader.searchResults.flatMap { $0.thumbnailURL.map { [$0] } ?? [] }
                }
            case .Hypem:
                return vc.blogLoader.blogs.flatMap { $0.thumbnailURL.map { [$0] } ?? [] }
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
    var userLoader:       SoundCloudUserLoader!
    var userObserver:     Disposable?

    init(streamListLoader: StreamListLoader) {
        self.streamListLoader = streamListLoader
        self.blogLoader       = BlogLoader()
        self.channelLoader    = ChannelLoader()
        self.userLoader       = SoundCloudUserLoader()
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
        observeUserLoader()
        fetchRecommendFeeds()
        fetchBlogs()
        if YouTubeAPIClient.isLoggedIn {
            channelLoader.fetchSubscriptions()
        } else {
            channelLoader.searchChannels("music")
        }
        if SoundCloudKit.APIClient.isLoggedIn {
            userLoader.fetchFollowings()
        } else {
            userLoader.searchUsers("rock")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        tableView.reloadData()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        blogObserver?.dispose()
        channelObserver?.dispose()
        userObserver?.dispose()
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

    func observeUserLoader() {
        userObserver?.dispose()
        userObserver = userLoader.signal.observe(next: { event in
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
        let vc = SearchStreamPageMenuController(streamListLoader: streamListLoader,
                                                      blogLoader: blogLoader,
                                                   channelLoader: channelLoader)
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
            cell.nameLabel?.text = menu.title!
            cell.setThumbnailImages(menu.thumbnailUrls(self))
        }
        return cell
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let menu = Menu(rawValue: indexPath.item) {
            switch menu {
            case .Recommend:
                let vc = StreamTableViewController(streamListLoader: streamListLoader,
                                                               type: .Recommend(recommendFeeds))
                navigationController?.pushViewController(vc, animated: true)
            case .YouTube:
                let vc = ChannelCategoryTableViewController(streamListLoader: streamListLoader, channelLoader: channelLoader)
                navigationController?.pushViewController(vc, animated: true)
                vc.showYouTubeLoginViewController()
            case .SoundCloud:
                if SoundCloudKit.APIClient.isLoggedIn {
                    let vc = SoundCloudUserTableViewController(streamListLoader: streamListLoader,
                                                                     userLoader: SoundCloudUserLoader(),
                                                                           type: .Followings)
                    navigationController?.pushViewController(vc, animated: true)
                } else {
                    let vc = SoundCloudUserTableViewController(streamListLoader: streamListLoader,
                                                                     userLoader: SoundCloudUserLoader(),
                                                                           type: .Search("rock"))
                    navigationController?.pushViewController(vc, animated: true)
                    vc.showSoundCloudLoginViewController()
                }
            case .Hypem:
                let vc = StreamTableViewController(streamListLoader: streamListLoader,
                                                               type: .Hypem(blogLoader))
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return cellHeight
    }
}
