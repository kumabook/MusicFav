//
//  ChannelTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 7/11/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveSwift
import SwiftyJSON
import FeedlyKit
import PageMenu
import MusicFeeder

class ChannelTableViewController: AddStreamTableViewController {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let cellReuseIdentifier = "ChannelTableViewCell"

    enum ChannelType {
        case category(GuideCategory)
        case search(String)
    }

    var observer:            Disposable?
    var type:                ChannelType
    let channelLoader:       ChannelLoader!
    var indicator:           UIActivityIndicatorView!
    var reloadButton:        UIButton!
    var channels:            [Channel] {
        switch type {
        case .category(let category):
            if let list = channelLoader.channelsOf(category) { return list }
            else                                             { return [] }
        case .search:
            return channelLoader.searchResults
        }
    }

    init(subscriptionRepository: SubscriptionRepository, channelLoader: ChannelLoader, type: ChannelType) {
        self.channelLoader = channelLoader
        self.type          = type
        super.init(subscriptionRepository: subscriptionRepository)
    }

    required init(coder aDecoder: NSCoder) {
        self.type          = .search("music")
        self.channelLoader = nil
        super.init(coder: aDecoder)
    }

    func refresh(_ type: ChannelType) {
        self.type = type
        channelLoader.clearSearch()
        reloadData(false)
        observeChannelLoader()
        fetchNext()
    }

    override func getSubscribables() -> [FeedlyKit.Stream] {
        if let indexPaths = tableView.indexPathsForSelectedRows {
            return indexPaths.map { self.channels[$0.item] }
        } else {
            return []
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "StreamTableViewCell", bundle: Bundle.main)
        tableView.register(nib, forCellReuseIdentifier: cellReuseIdentifier)

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
        reloadButton.addTarget(self, action:#selector(ChannelTableViewController.fetchNext), for:UIControlEvents.touchUpInside)
        reloadButton.setTitle("Sorry, network error occured.".localize(), for:UIControlState.normal)
        reloadButton.frame = CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 44);
        refresh(type)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        observeChannelLoader()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        observer?.dispose()
        observer = nil
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
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if tableView.contentOffset.y >= tableView.contentSize.height - tableView.bounds.size.height {
            fetchNext()
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

    @objc func fetchNext() {
        switch type {
        case .category(let category):
            channelLoader.fetchChannels(category)
        case .search(let query):
            channelLoader.searchChannels(query)
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return cellHeight
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return channels.count
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath) as! StreamTableViewCell
        setAccessoryView(cell, indexPath: indexPath)
        let channel = channels[indexPath.item]
        cell.titleLabel.text = channel.title
        if let url = URL(string: channel.thumbnails["default"]!) {
            cell.thumbImageView.sd_setImage(with: url)
        }
        cell.subtitle1Label.text          = ""
        cell.subtitle2Label.text          = channel.description
        cell.subtitle2Label.numberOfLines = 2
        cell.subtitle2Label.textAlignment = .left
        return cell
    }
}
