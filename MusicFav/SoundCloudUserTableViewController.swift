//
//  SoundCloudUserTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/24/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveSwift
import SwiftyJSON
import FeedlyKit
import PageMenu
import MusicFeeder
import SoundCloudKit

class SoundCloudUserTableViewController: AddStreamTableViewController {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let cellReuseIdentifier = "ChannelTableViewCell"

    enum `Type` {
        case followings
        case search(String)
    }

    var observer:            Disposable?
    var type:                Type
    let userLoader:          SoundCloudUserLoader!
    var indicator:           UIActivityIndicatorView!
    var reloadButton:        UIButton!
    var users:               [SoundCloudKit.User] {
        switch type {
        case .followings:
            return userLoader.followings
        case .search:
            return userLoader.searchResults
        }
    }

    init(streamRepository: StreamRepository, userLoader: SoundCloudUserLoader, type: Type) {
        self.userLoader = userLoader
        self.type       = type
        super.init(streamRepository: streamRepository)
    }

    required init(coder aDecoder: NSCoder) {
        self.userLoader    = nil
        self.type          = .search("music")
        super.init(coder: aDecoder)
    }

    func refresh(_ type: Type) {
        self.type = type
        userLoader.clearSearch()
        reloadData(false)
        observeUserLoader()
        fetchNext()
    }

    override func getSubscribables() -> [FeedlyKit.Stream] {
        if let indexPaths = tableView.indexPathsForSelectedRows {
            return indexPaths.map { return self.users[$0.item].toSubscription() as FeedlyKit.Stream }
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
        reloadButton.addTarget(self, action:#selector(SoundCloudUserTableViewController.fetchNext), for:UIControlEvents.touchUpInside)
        reloadButton.setTitle("Sorry, network error occured.".localize(), for:UIControlState.normal)
        reloadButton.frame = CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 44);
        refresh(type)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        observeUserLoader()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        observer?.dispose()
        observer = nil
    }

    func observeUserLoader() {
        observer?.dispose()
        observer = userLoader.signal.observeResult({ result in
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

    func fetchNext() {
        switch type {
        case .followings:
            userLoader.fetchFollowings()
        case .search(let query):
            userLoader.searchUsers(query)
        }
    }

    func showSoundCloudLoginViewController() {
        if !SoundCloudKit.APIClient.isLoggedIn {
            navigationController?.pushViewController(SoundCloudOAuthViewController(), animated: true)
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
        return users.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath) as! StreamTableViewCell
        setAccessoryView(cell, indexPath: indexPath)
        let user = users[indexPath.item]
        cell.titleLabel.text = user.username
        if let url = user.thumbnailURL {
            cell.thumbImageView.sd_setImage(with: url)
        }
        cell.subtitle1Label.text          = ""
        cell.subtitle2Label.text          = user.description
        cell.subtitle2Label.numberOfLines = 2
        cell.subtitle2Label.textAlignment = .left
        return cell
    }
}
