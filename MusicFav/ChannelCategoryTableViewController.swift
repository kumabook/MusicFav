//
//  ChannelCategoryTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 7/11/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveSwift
import SwiftyJSON
import FeedlyKit
import MusicFeeder
import MBProgressHUD
import YouTubeKit

class ChannelCategoryTableViewController: AddStreamTableViewController {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    enum Section: Int {
        case subscriptions = 0
        case guideCategory = 1
        static let count   = 2
        var title: String? {
            switch self {
            case .subscriptions:
                if YouTubeAPIClient.isLoggedIn {
                    return "Your subscriptions"
                } else {
                    return nil
                }
            case .guideCategory:
                return "Category"
            }
        }
        var tableCellReuseIdentifier: String {
            switch self {
            case .subscriptions:
                if YouTubeAPIClient.isLoggedIn {
                    return "Subscriptions"
                } else {
                    return "Login"
                }
            case .guideCategory:
                return "Category"
            }
        }
        var cellHeight: CGFloat {
            switch self {
            case .subscriptions:
                if YouTubeAPIClient.isLoggedIn {
                    return 100
                } else {
                    return 60
                }
            case .guideCategory:
                return 60
            }
        }
    }

    var observer:            Disposable?
    let channelLoader:       ChannelLoader!
    var indicator:           UIActivityIndicatorView!
    var reloadButton:        UIButton!

    init(subscriptionRepository: SubscriptionRepository, channelLoader: ChannelLoader) {
        self.channelLoader = channelLoader
        super.init(subscriptionRepository: subscriptionRepository)
    }

    required init(coder aDecoder: NSCoder) {
        channelLoader    = ChannelLoader()
        super.init(coder: aDecoder)
    }

    override func getSubscribables() -> [FeedlyKit.Stream] {
        if let indexPaths = tableView.indexPathsForSelectedRows {
            return indexPaths.map { ChannelStream(channel: Channel(subscription: self.channelLoader.subscriptions[$0.item])) }
        } else {
            return []
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "StreamTableViewCell", bundle: Bundle.main)
        tableView.register(nib, forCellReuseIdentifier: "Subscriptions")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Login")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Section.guideCategory.tableCellReuseIdentifier)

        navigationItem.rightBarButtonItem = UIBarButtonItem(title:"Add".localize(),
                                                            style: UIBarButtonItemStyle.plain,
                                                           target: self,
                                                           action: #selector(ChannelCategoryTableViewController.add))

        indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
        indicator.bounds = CGRect(x: 0,
                                  y: 0,
                              width: indicator.bounds.width,
                             height: indicator.bounds.height * 3)
        indicator.hidesWhenStopped = true
        indicator.stopAnimating()

        reloadButton = UIButton()
        reloadButton.setImage(UIImage(named: "network_error"), for: UIControlState())
        reloadButton.setTitleColor(UIColor.black, for: UIControlState())
        reloadButton.addTarget(self, action:#selector(ChannelCategoryTableViewController.refresh), for:UIControlEvents.touchUpInside)
        reloadButton.setTitle("Sorry, network error occured.".localize(), for:UIControlState.normal)
        reloadButton.frame = CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 44);
        tableView.allowsMultipleSelection = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateAddButton()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        observeChannelLoader()
        channelLoader.fetchSubscriptions()
        channelLoader.fetchCategories()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        observer?.dispose()
        observer = nil
    }

    @objc func refresh() {
        channelLoader.fetchCategories()
    }

    func observeChannelLoader() {
        observer?.dispose()
        observer = channelLoader.signal.observeResult({ result in
            guard let event = result.value else { return }
            switch event {
            case .startLoading:
                self.showIndicator()
            case .completeLoading:
                self.hideIndicator()
                self.reloadData(true)
            case .failToLoad:
                self.showReloadButton()
            }
        })
        reloadData(true)
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
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
            YouTubeAPIClient.authorize(self)
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return Section(rawValue: indexPath.section)!.cellHeight
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .subscriptions:
            if YouTubeAPIClient.isLoggedIn {
                return channelLoader.subscriptions.count
            } else {
                return 1
            }
        case .guideCategory:
            return channelLoader.categories.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = Section(rawValue: indexPath.section)!
        switch section {
        case .subscriptions:
            if YouTubeAPIClient.isLoggedIn {
                let cell = tableView.dequeueReusableCell(withIdentifier: section.tableCellReuseIdentifier, for: indexPath) as! StreamTableViewCell
                setAccessoryView(cell, indexPath: indexPath)
                let subscription = channelLoader.subscriptions[indexPath.item]
                cell.titleLabel.text = subscription.title
                if let url = URL(string: subscription.thumbnails["default"]!) {
                    cell.thumbImageView.sd_setImage(with: url)
                }
                cell.subtitle1Label.text          = ""
                cell.subtitle2Label.text          = subscription.description
                cell.subtitle2Label.numberOfLines = 2
                cell.subtitle2Label.textAlignment = .left
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: section.tableCellReuseIdentifier, for: indexPath)
                cell.textLabel?.text = "Connect with Your YouTube Account"
                return cell
            }
        case .guideCategory:
            let cell = tableView.dequeueReusableCell(withIdentifier: section.tableCellReuseIdentifier, for: indexPath)
            let category = channelLoader.categories[indexPath.item]
            cell.textLabel?.text = category.title
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .subscriptions:
            if YouTubeAPIClient.isLoggedIn {
                super.tableView(tableView, didSelectRowAt: indexPath)
            } else {
                showYouTubeLoginViewController()
            }
        case .guideCategory:
            let vc = ChannelTableViewController(subscriptionRepository: subscriptionRepository,
                                                         channelLoader: channelLoader,
                                                                  type: .category(channelLoader.categories[indexPath.item]))
            navigationController?.pushViewController(vc, animated: true)
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
}
