//
//  AddStreamMenuViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/1/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveSwift
import MusicFeeder
import FeedlyKit
import SoundCloudKit

class AddStreamMenuViewController: UITableViewController, UISearchBarDelegate {
    let reuseIdentifier = "reuseIdentifier"
    let cellHeight:        CGFloat = 120
    let accessoryWidth:    CGFloat = 30
    let SEARCH_BAR_HEIGHT: CGFloat = 40
    enum Menu: Int {
        case recommend
        case youTube
        case hypem
        case soundCloud
        static let count = 3
        var title: String? {
            switch self {
            case .recommend:
                return "MusicFav Recommend".localize()
            case .youTube:
                return "YouTube"
            case .soundCloud:
                return "SoundCloud"
            case .hypem:
                return "Hype machine featured".localize()
            }
        }
        func thumbnailUrls(_ vc: AddStreamMenuViewController) -> [URL] {
            switch self {
            case .recommend:
                return vc.recommendFeeds.flatMap { $0.thumbnailURL.map { [$0] } ?? [] }
            case .youTube:
                if YouTubeAPIClient.isLoggedIn {
                    return vc.channelLoader.subscriptions.flatMap { $0.thumbnailURL.map { [$0] } ?? [] }
                } else {
                    return vc.channelLoader.searchResults.flatMap { $0.thumbnailURL.map { [$0] } ?? [] }
                }
            case .soundCloud:
                if SoundCloudKit.APIClient.isLoggedIn {
                    return vc.userLoader.followings.flatMap { $0.thumbnailURL.map { [$0] } ?? [] }
                } else {
                    return vc.userLoader.searchResults.flatMap { $0.thumbnailURL.map { [$0] } ?? [] }
                }
            case .hypem:
                return vc.blogLoader.blogs.flatMap { $0.thumbnailURL.map { [$0] } ?? [] }
            }
        }
    }

    var indicator: UIActivityIndicatorView!
    var searchBar: UISearchBar!

    var subscriptionRepository: SubscriptionRepository!
    var recommendFeeds:         [Feed]
    let blogLoader:             BlogLoader
    var blogObserver:           Disposable?
    var channelLoader:          ChannelLoader!
    var channelObserver:        Disposable?
    var userLoader:             SoundCloudUserLoader!
    var userObserver:           Disposable?

    init(subscriptionRepository: SubscriptionRepository) {
        self.subscriptionRepository = subscriptionRepository
        self.blogLoader             = BlogLoader()
        self.channelLoader          = ChannelLoader()
        self.userLoader             = SoundCloudUserLoader()
        self.recommendFeeds         = []
        super.init(nibName: nil, bundle: nil)
    }

    required init(coder aDecoder: NSCoder) {
        subscriptionRepository = SubscriptionRepository()
        blogLoader             = BlogLoader()
        channelLoader          = ChannelLoader()
        recommendFeeds         = []
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView?.register(UINib(nibName: "AddStreamMenuTableViewCell", bundle: nil) , forCellReuseIdentifier: reuseIdentifier)
        navigationItem.leftBarButtonItem = UIBarButtonItem(title:"Close".localize(),
                                                           style: UIBarButtonItemStyle.plain,
                                                          target: self,
                                                          action: #selector(AddStreamMenuViewController.close))
        navigationItem.rightBarButtonItem?.isEnabled = false
        searchBar                 = UISearchBar(frame:CGRect(x: 0, y: 0, width: view.bounds.size.width, height: SEARCH_BAR_HEIGHT))
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        blogObserver?.dispose()
        channelObserver?.dispose()
        userObserver?.dispose()
    }

    func close() {
        dismiss(animated: true, completion: {})
    }

    func fetchRecommendFeeds() {
        CloudAPIClient.shared.fetchFeedsByIds(feedIds: RecommendFeed.ids).on(
            failed: { error in
        }, completed: {
            self.tableView?.reloadData()
        }, value: { feeds in
            self.recommendFeeds = feeds
        }).start()
    }

    func observeBlogLoader() {
        blogObserver?.dispose()
        blogObserver = blogLoader.signal.observeResult({ result in
            guard let event = result.value else { return }
            switch event {
            case .startLoading:    break
            case .completeLoading: self.tableView?.reloadData()
            case .failToLoad:      break
            }
        })
    }

    func observeChannelLoader() {
        channelObserver?.dispose()
        channelObserver = channelLoader.signal.observeResult({ result in
            guard let event = result.value else { return }
            switch event {
            case .startLoading: break
            case .completeLoading:
                self.tableView.reloadData()
            case .failToLoad: break
            }
        })
    }

    func observeUserLoader() {
        userObserver?.dispose()
        userObserver = userLoader.signal.observeResult({ result in
            guard let event = result.value else { return }
            switch event {
            case .startLoading: break
            case .completeLoading:
                self.tableView.reloadData()
            case .failToLoad: break
            }
        })
    }

    func fetchBlogs() {
        blogLoader.fetchBlogs()
    }

    // MARK: - UISearchBarDelegate

    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        let vc = SearchStreamPageMenuController(subscriptionRepository: subscriptionRepository,
                                                            blogLoader: blogLoader,
                                                         channelLoader: channelLoader)
        vc.modalTransitionStyle = UIModalTransitionStyle.flipHorizontal
        present(UINavigationController(rootViewController: vc), animated: true, completion: {})
        return false
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Menu.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! AddStreamMenuTableViewCell
        if let menu = Menu(rawValue: indexPath.item) {
            cell.nameLabel?.text = menu.title!
            cell.setThumbnailImages(menu.thumbnailUrls(self))
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let menu = Menu(rawValue: indexPath.item) {
            switch menu {
            case .recommend:
                let vc = StreamTableViewController(subscriptionRepository: subscriptionRepository,
                                                                     type: .recommend(recommendFeeds))
                navigationController?.pushViewController(vc, animated: true)
            case .youTube:
                let vc = ChannelCategoryTableViewController(subscriptionRepository: subscriptionRepository, channelLoader: channelLoader)
                navigationController?.pushViewController(vc, animated: true)
                vc.showYouTubeLoginViewController()
            case .soundCloud:
                if SoundCloudKit.APIClient.isLoggedIn {
                    let vc = SoundCloudUserTableViewController(subscriptionRepository: subscriptionRepository,
                                                                           userLoader: SoundCloudUserLoader(),
                                                                                 type: .followings)
                    navigationController?.pushViewController(vc, animated: true)
                } else {
                    let vc = SoundCloudUserTableViewController(subscriptionRepository: subscriptionRepository,
                                                                           userLoader: SoundCloudUserLoader(),
                                                                                 type: .search("rock"))
                    navigationController?.pushViewController(vc, animated: true)
                    vc.showSoundCloudLoginViewController()
                }
            case .hypem:
                let vc = StreamTableViewController(subscriptionRepository: subscriptionRepository,
                                                                     type: .hypem(blogLoader))
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return cellHeight
    }
}
