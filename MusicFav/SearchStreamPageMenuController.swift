//
//  SearchStreamPageMenuController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/17/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import PageMenu
import MusicFeeder
import FeedlyKit
import MBProgressHUD
import ReactiveSwift

class SearchStreamPageMenuController: UIViewController, UISearchBarDelegate {
         var searchBar:      UISearchBar!
         var pageMenu:       CAPSPageMenu!
    weak var feedlyStreamViewController: StreamTableViewController?
    weak var channelTableViewController: ChannelTableViewController?
    weak var userTableViewController:    SoundCloudUserTableViewController?

    var subscriptionRepository: SubscriptionRepository
    var blogLoader:             BlogLoader
    var channelLoader:          ChannelLoader

    init(subscriptionRepository: SubscriptionRepository, blogLoader: BlogLoader, channelLoader: ChannelLoader) {
        self.subscriptionRepository = subscriptionRepository
        self.blogLoader             = blogLoader
        self.channelLoader          = channelLoader
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        subscriptionRepository = SubscriptionRepository()
        blogLoader             = BlogLoader()
        channelLoader          = ChannelLoader()
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.toolbar.isTranslucent       = false
        self.navigationController?.navigationBar.isTranslucent = false
        navigationItem.leftBarButtonItem = UIBarButtonItem(title:"Back".localize(),
                                                           style: UIBarButtonItemStyle.plain,
                                                          target: self,
                                                          action: #selector(SearchStreamPageMenuController.back))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title:"Add".localize(),
                                                            style: UIBarButtonItemStyle.plain,
                                                           target: self,
                                                           action: #selector(SearchStreamPageMenuController.add))
        searchBar                        = UISearchBar(frame: navigationController!.navigationBar.bounds)
        searchBar.placeholder            = "URL or keywords"
        searchBar.autocapitalizationType = UITextAutocapitalizationType.none
        searchBar.keyboardType           = UIKeyboardType.default
        searchBar.delegate               = self
        navigationItem.titleView         = searchBar
        navigationItem.titleView?.frame  = searchBar.frame
        searchBar.becomeFirstResponder()
        Logger.sendUIActionEvent(self, action: "searchFeeds", label: "")
        let feedlyStreamVC = StreamTableViewController(subscriptionRepository: subscriptionRepository, type: .search(""))
        let channelVC      = ChannelTableViewController(subscriptionRepository: subscriptionRepository, channelLoader: channelLoader, type: .search(""))
//        let userVC         = SoundCloudUserTableViewController(streamListLoader: streamListLoader, userLoader: SoundCloudUserLoader(), type: .Search(""))

        channelLoader.searchResults = []

        feedlyStreamVC.title = "Feedly"
        channelVC.title      = "YouTube"
//        userVC.title         = "SoundCloud"
        let controllerArray: [UIViewController] = [feedlyStreamVC, channelVC]//, userVC]
        let parameters: [CAPSPageMenuOption] = [
            .menuItemSeparatorWidth(0.0),
            .useMenuLikeSegmentedControl(true),
            .menuItemSeparatorPercentageHeight(0.0),
            .menuHeight(24),
            .scrollMenuBackgroundColor(UIColor.white),
            .selectionIndicatorColor(UIColor.theme),
            .selectedMenuItemLabelColor(UIColor.theme),
            .unselectedMenuItemLabelColor(UIColor.gray),
            .menuItemSeparatorColor(UIColor.lightGray),
            .bottomMenuHairlineColor(UIColor.lightGray),
            .menuItemFont(UIFont.boldSystemFont(ofSize: 14))
        ]
        pageMenu = CAPSPageMenu(viewControllers: controllerArray,
            frame: view.frame,
            pageMenuOptions: parameters)
        view.addSubview(pageMenu.view)
        addChildViewController(pageMenu)
        pageMenu.didMove(toParentViewController: self)
        super.viewDidLoad()
        updateAddButton()
        feedlyStreamViewController = feedlyStreamVC
        channelTableViewController = channelVC
//        userTableViewController    = userVC
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func getSubscribables() -> [FeedlyKit.Stream] {
        var subscribables: [FeedlyKit.Stream] = []
        subscribables.append(contentsOf: feedlyStreamViewController?.getSubscribables() ?? [] )
        subscribables.append(contentsOf: channelTableViewController?.getSubscribables() ?? [] )
        subscribables.append(contentsOf: userTableViewController?.getSubscribables() ?? [] )
        return subscribables
    }

    func back() {
        dismiss(animated: true, completion: {})
    }

    func close() {
        navigationController?.dismiss(animated: true, completion: {})
        navigationController?.presentingViewController?.dismiss(animated: true, completion: {})
    }

    func add() {
        let ctc = CategoryTableViewController(subscribables: getSubscribables(), subscriptionRepository: subscriptionRepository)
        navigationController?.pushViewController(ctc, animated: true)
    }

    func updateAddButton() {
        navigationItem.rightBarButtonItem?.isEnabled = getSubscribables().count > 0
    }

    func needSearch() -> Bool {
        return searchBar.text != ""
    }

    func searchFeeds(_ query: String) {
        feedlyStreamViewController?.refresh(.search(query))
        channelTableViewController?.refresh(.search(query))
        userTableViewController?.refresh(.search(query))
        updateAddButton()
    }

    // MARK: - UISearchBar delegate

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchFeeds(searchBar.text!)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchFeeds(searchBar.text!)
    }
}
