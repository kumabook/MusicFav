//
//  SoundCloudUserTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/24/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import SwiftyJSON
import FeedlyKit
import PageMenu
import MusicFeeder
import SoundCloudKit

class SoundCloudUserTableViewController: AddStreamTableViewController {
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    let cellReuseIdentifier = "ChannelTableViewCell"

    enum Type {
        case Followings
        case Search(String)
    }

    var observer:            Disposable?
    var type:                Type
    let userLoader:          SoundCloudUserLoader!
    var indicator:           UIActivityIndicatorView!
    var reloadButton:        UIButton!
    var users:               [SoundCloudKit.User] {
        switch type {
        case .Followings:
            return userLoader.followings
        case .Search:
            return userLoader.searchResults
        }
    }

    init(streamListLoader: StreamListLoader, userLoader: SoundCloudUserLoader, type: Type) {
        self.userLoader = userLoader
        self.type       = type
        super.init(streamListLoader: streamListLoader)
    }

    required init(coder aDecoder: NSCoder) {
        self.userLoader    = nil
        self.type          = .Search("music")
        super.init(coder: aDecoder)
    }

    func refresh(type: Type) {
        self.type = type
        userLoader.clearSearch()
        reloadData(keepSelection: false)
        observeUserLoader()
        fetchNext()
    }

    override func getSubscribables() -> [Stream] {
        if let indexPaths = tableView.indexPathsForSelectedRows {
            return indexPaths.map { return self.users[$0.item].toSubscription() as Stream }
        } else {
            return []
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "StreamTableViewCell", bundle: NSBundle.mainBundle())
        tableView.registerNib(nib, forCellReuseIdentifier: cellReuseIdentifier)

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
        reloadButton.addTarget(self, action:"fetchNext", forControlEvents:UIControlEvents.TouchUpInside)
        reloadButton.setTitle("Sorry, network error occured.".localize(), forState:UIControlState.Normal)
        reloadButton.frame = CGRectMake(0, 0, tableView.frame.size.width, 44);
        refresh(type)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        observeUserLoader()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        observer?.dispose()
        observer = nil
    }

    func observeUserLoader() {
        observer?.dispose()
        observer = userLoader.signal.observeNext({ event in
            switch event {
            case .StartLoading:
                self.showIndicator()
            case .CompleteLoading:
                self.hideIndicator()
                self.reloadData(keepSelection: true)
            case .FailToLoad:
                self.showReloadButton()
            }
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func scrollViewDidScroll(scrollView: UIScrollView) {
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
        case .Followings:
            userLoader.fetchFollowings()
        case .Search(let query):
            userLoader.searchUsers(query)
        }
    }

    func showSoundCloudLoginViewController() {
        if !SoundCloudKit.APIClient.isLoggedIn {
            navigationController?.pushViewController(SoundCloudOAuthViewController(), animated: true)
        }
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return cellHeight
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(cellReuseIdentifier, forIndexPath: indexPath) as! StreamTableViewCell
        setAccessoryView(cell, indexPath: indexPath)
        let user = users[indexPath.item]
        cell.titleLabel.text = user.username
        if let url = user.thumbnailURL {
            cell.thumbImageView.sd_setImageWithURL(url)
        }
        cell.subtitle1Label.text          = ""
        cell.subtitle2Label.text          = user.description
        cell.subtitle2Label.numberOfLines = 2
        cell.subtitle2Label.textAlignment = .Left
        return cell
    }
}
