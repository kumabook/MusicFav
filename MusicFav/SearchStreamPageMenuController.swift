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
import ReactiveCocoa

class SearchStreamPageMenuController: UIViewController, UISearchBarDelegate {
         var searchBar:      UISearchBar!
         var pageMenu:       CAPSPageMenu!
    weak var feedlyStreamViewController: StreamTableViewController?
    weak var channelTableViewController: ChannelTableViewController?

    var streamListLoader: StreamListLoader
    var blogLoader:       BlogLoader
    var channelLoader:    ChannelLoader

    init(streamListLoader: StreamListLoader, blogLoader: BlogLoader, channelLoader: ChannelLoader) {
        self.streamListLoader = streamListLoader
        self.blogLoader       = blogLoader
        self.channelLoader    = channelLoader
        super.init(nibName: nil, bundle: nil)
    }

    required init(coder aDecoder: NSCoder) {
        streamListLoader = StreamListLoader()
        blogLoader       = BlogLoader()
        channelLoader    = ChannelLoader()
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.toolbar.translucent       = false
        self.navigationController?.navigationBar.translucent = false
        navigationItem.leftBarButtonItem = UIBarButtonItem(title:"Back".localize(),
                                                           style: UIBarButtonItemStyle.Plain,
                                                          target: self,
                                                          action: "back")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title:"Add".localize(),
                                                            style: UIBarButtonItemStyle.Plain,
                                                           target: self,
                                                           action: "add")
        searchBar                        = UISearchBar(frame: navigationController!.navigationBar.bounds)
        searchBar.placeholder            = "URL or keywords"
        searchBar.autocapitalizationType = UITextAutocapitalizationType.None
        searchBar.keyboardType           = UIKeyboardType.Default
        searchBar.delegate               = self
        navigationItem.titleView         = searchBar
        navigationItem.titleView?.frame  = searchBar.frame
        searchBar.becomeFirstResponder()
        Logger.sendUIActionEvent(self, action: "searchFeeds", label: "")
        let feedlyStreamVC = StreamTableViewController(streamListLoader: streamListLoader, type: .Search(""))
        let channelVC      = ChannelTableViewController(streamListLoader: streamListLoader, channelLoader: channelLoader, type: .Search(""))

        channelLoader.searchResults = []

        feedlyStreamVC.title = "Feedly"
        channelVC.title      = "YouTube"
        var controllerArray: [UIViewController] = [feedlyStreamVC, channelVC]
        var parameters: [CAPSPageMenuOption] = [
            .MenuItemSeparatorWidth(0.0),
            .UseMenuLikeSegmentedControl(true),
            .MenuItemSeparatorPercentageHeight(0.0),
            .MenuHeight(24),
            .ScrollMenuBackgroundColor(UIColor.whiteColor()),
            .SelectionIndicatorColor(UIColor.theme),
            .SelectedMenuItemLabelColor(UIColor.theme),
            .UnselectedMenuItemLabelColor(UIColor.grayColor()),
            .MenuItemSeparatorColor(UIColor.lightGray),
            .BottomMenuHairlineColor(UIColor.lightGray),
            .MenuItemFont(UIFont.boldSystemFontOfSize(14))
        ]
        pageMenu = CAPSPageMenu(viewControllers: controllerArray,
            frame: view.frame,
            pageMenuOptions: parameters)
        view.addSubview(pageMenu.view)
        addChildViewController(pageMenu)
        pageMenu.didMoveToParentViewController(self)
        super.viewDidLoad()
        updateAddButton()
        feedlyStreamViewController = feedlyStreamVC
        channelTableViewController = channelVC
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func getSubscribables() -> [Stream] {
        var subscribables: [Stream] = []
        subscribables.extend(feedlyStreamViewController?.getSubscribables() ?? [] )
        subscribables.extend(channelTableViewController?.getSubscribables() ?? [] )
        return subscribables
    }

    func back() {
        dismissViewControllerAnimated(true, completion: {})
    }

    func close() {
        navigationController?.dismissViewControllerAnimated(true, completion: {})
        navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: {})
    }

    func add() {
        if CloudAPIClient.isLoggedIn {
            let ctc = CategoryTableViewController(subscribables: getSubscribables(), streamListLoader: streamListLoader)
            navigationController?.pushViewController(ctc, animated: true)
        } else {
            MBProgressHUD.showHUDAddedTo(self.navigationController!.view, animated: true)
            getSubscribables().reduce(SignalProducer<[Subscription], NSError>(value: [])) {
                combineLatest($0, self.streamListLoader.subscribeTo($1, categories: [])) |> map {
                    var list = $0.0; list.append($0.1); return list
                }
            } |> start(
                next: { subscriptions in
                    if let view = self.navigationController?.view {
                        MBProgressHUD.hideHUDForView(view, animated:false)
                    }
                }, error: { e in
                    if let view = self.navigationController?.view {
                        MBProgressHUD.hideHUDForView(view, animated:false)
                    }
                    let ac = CloudAPIClient.alertController(error: e, handler: { (action) in })
                }, completed: {
                    if let view = self.navigationController?.view {
                        MBProgressHUD.showCompletedHUDForView(view, animated: true, duration: 1.0) {
                            self.streamListLoader.refresh()
                            self.close()
                        }
                    }
            })
        }
    }

    func updateAddButton() {
        navigationItem.rightBarButtonItem?.enabled = getSubscribables().count > 0
    }

    func needSearch() -> Bool {
        return searchBar.text != ""
    }

    func searchFeeds(query: String) {
        feedlyStreamViewController?.refresh(.Search(query))
        channelTableViewController?.refresh(.Search(query))
        updateAddButton()
    }

    // MARK: - UISearchBar delegate

    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        searchFeeds(searchBar.text)
    }

    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        searchFeeds(searchBar.text)
    }
}