//
//  ChannelCategoryTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 7/11/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import SwiftyJSON
import FeedlyKit
import PageMenu
import MusicFeeder
import MBProgressHUD

class ChannelCategoryTableViewController: AddStreamTableViewController {
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate

    enum Section: Int {
        case Subscriptions = 0
        case GuideCategory = 1
        static let count   = 2
        var title: String? {
            switch self {
            case .Subscriptions:
                if YouTubeAPIClient.isLoggedIn {
                    return "Your subscriptions"
                } else {
                    return nil
                }
            case .GuideCategory:
                return "Category"
            }
        }
        var tableCellReuseIdentifier: String {
            switch self {
            case .Subscriptions:
                if YouTubeAPIClient.isLoggedIn {
                    return "Subscriptions"
                } else {
                    return "Login"
                }
            case .GuideCategory:
                return "Category"
            }
        }
        var cellHeight: CGFloat {
            switch self {
            case .Subscriptions:
                if YouTubeAPIClient.isLoggedIn {
                    return 100
                } else {
                    return 60
                }
            case .GuideCategory:
                return 60
            }
        }
    }

    var observer:            Disposable?
    let channelLoader:       ChannelLoader!
    var indicator:           UIActivityIndicatorView!
    var reloadButton:        UIButton!

    init(streamListLoader: StreamListLoader, channelLoader: ChannelLoader) {
        self.channelLoader    = channelLoader
        super.init(streamListLoader: streamListLoader)
    }

    required init(coder aDecoder: NSCoder) {
        channelLoader    = ChannelLoader()
        super.init(coder: aDecoder)
    }

    override func getSubscribables() -> [Stream] {
        if let indexPaths = tableView.indexPathsForSelectedRows() {
            return indexPaths.map { Channel(subscription: self.channelLoader.subscriptions[$0.item]) }
        } else {
            return []
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "StreamTableViewCell", bundle: NSBundle.mainBundle())
        tableView.registerNib(nib, forCellReuseIdentifier: "Subscriptions")
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "Login")
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: Section.GuideCategory.tableCellReuseIdentifier)

        navigationItem.rightBarButtonItem = UIBarButtonItem(title:"Add".localize(),
                                                            style: UIBarButtonItemStyle.Plain,
                                                           target: self,
                                                           action: "add")

        indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
        indicator.bounds = CGRect(x: 0,
                                  y: 0,
                              width: indicator.bounds.width,
                             height: indicator.bounds.height * 3)
        indicator.hidesWhenStopped = true
        indicator.stopAnimating()

        reloadButton = UIButton()
        reloadButton.setImage(UIImage(named: "network_error"), forState: UIControlState.Normal)
        reloadButton.setTitleColor(UIColor.blackColor(), forState: UIControlState.Normal)
        reloadButton.addTarget(self, action:"refresh", forControlEvents:UIControlEvents.TouchUpInside)
        reloadButton.setTitle("Sorry, network error occured.".localize(), forState:UIControlState.Normal)
        reloadButton.frame = CGRectMake(0, 0, tableView.frame.size.width, 44);
        tableView.allowsMultipleSelection = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        updateAddButton()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        observeChannelLoader()
        channelLoader.fetchSubscriptions()
        channelLoader.fetchCategories()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        observer?.dispose()
        observer = nil
    }

    func refresh() {
        channelLoader.fetchCategories()
    }

    func observeChannelLoader() {
        observer?.dispose()
        observer = channelLoader.signal.observe(next: { event in
            switch event {
            case .StartLoading:
                self.showIndicator()
            case .CompleteLoading:
                self.hideIndicator()
                self.tableView.reloadData()
            case .FailToLoad:
                self.showReloadButton()
            }
        })
        tableView?.reloadData()
    }

    override func scrollViewDidScroll(scrollView: UIScrollView) {
        if tableView.contentOffset.y >= tableView.contentSize.height - tableView.bounds.size.height {
            refresh()
        }
    }

    func showIndicator() {
        self.tableView.tableFooterView = indicator
        indicator?.startAnimating()
    }

    func hideIndicator() {
        indicator?.stopAnimating()
        self.tableView.tableFooterView = nil
    }

    func showReloadButton() {
        self.tableView.tableFooterView = reloadButton
    }

    func hideReloadButton() {
        self.tableView.tableFooterView = nil
    }

    func showYouTubeLoginViewController() {
        if !YouTubeAPIClient.isLoggedIn {
            let vc = OAuthViewController(clientId: YouTubeAPIClient.clientId,
                                     clientSecret: YouTubeAPIClient.clientSecret,
                                         scopeUrl: YouTubeAPIClient.scopeUrl,
                                          authUrl: YouTubeAPIClient.authUrl,
                                         tokenUrl: YouTubeAPIClient.tokenUrl,
                                      redirectUrl: YouTubeAPIClient.redirectUrl,
                                      accountType: YouTubeAPIClient.accountType,
                                    keyChainGroup: YouTubeAPIClient.keyChainGroup)
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return Section.count
    }

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return Section(rawValue: indexPath.section)!.cellHeight
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .Subscriptions:
            if YouTubeAPIClient.isLoggedIn {
                return channelLoader.subscriptions.count
            } else {
                return 1
            }
        case .GuideCategory:
            return channelLoader.categories.count
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let section = Section(rawValue: indexPath.section)!
        switch section {
        case .Subscriptions:
            if YouTubeAPIClient.isLoggedIn {
                let cell = tableView.dequeueReusableCellWithIdentifier(section.tableCellReuseIdentifier, forIndexPath: indexPath) as! StreamTableViewCell
                setAccessoryView(cell, indexPath: indexPath)
                let subscription = channelLoader.subscriptions[indexPath.item]
                cell.titleLabel.text = subscription.title
                if let url = NSURL(string: subscription.thumbnails["default"]!) {
                    cell.thumbImageView.sd_setImageWithURL(url)
                }
                cell.subtitle1Label.text = ""
                cell.subtitle2Label.text = ""
                return cell
            } else {
                let cell = tableView.dequeueReusableCellWithIdentifier(section.tableCellReuseIdentifier, forIndexPath: indexPath) as! UITableViewCell
                cell.textLabel?.text = "Connect with Your YouTube Account"
                return cell
            }
        case .GuideCategory:
            let cell = tableView.dequeueReusableCellWithIdentifier(section.tableCellReuseIdentifier, forIndexPath: indexPath) as! UITableViewCell
            let category = channelLoader.categories[indexPath.item]
            cell.textLabel?.text = category.title
            return cell
        }
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .Subscriptions:
            if YouTubeAPIClient.isLoggedIn {
                super.tableView(tableView, didSelectRowAtIndexPath: indexPath)
            } else {
                showYouTubeLoginViewController()
            }
        case .GuideCategory:
            let vc = ChannelTableViewController(streamListLoader: streamListLoader,
                                                        category: channelLoader.categories[indexPath.item],
                                                   channelLoader: channelLoader)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
