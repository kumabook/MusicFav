//
//  ChannelTableViewController.swift
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

class ChannelTableViewController: AddStreamTableViewController {
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    let cellReuseIdentifier = "ChannelTableViewCell"

    enum Type {
        case Category(GuideCategory)
        case Search(String)
    }

    var observer:            Disposable?
    var type:                Type
    let channelLoader:       ChannelLoader!
    var indicator:           UIActivityIndicatorView!
    var reloadButton:        UIButton!
    var channels:            [Channel] {
        switch type {
        case .Category(let category):
            if let list = channelLoader.channelsOf(category) { return list }
            else                                             { return [] }
        case .Search(let query):
            return channelLoader.searchResults
        default:
            return []
        }
    }

    init(streamListLoader: StreamListLoader, channelLoader: ChannelLoader, type: Type) {
        self.channelLoader = channelLoader
        self.type          = type
        super.init(streamListLoader: streamListLoader)
    }

    required init(coder aDecoder: NSCoder) {
        self.type          = .Search("music")
        self.channelLoader = nil
        super.init(coder: aDecoder)
    }

    func refresh(type: Type) {
        self.type = type
        channelLoader.clearSearch()
        reloadData(keepSelection: false)
        observeChannelLoader()
        fetchNext()
    }

    override func getSubscribables() -> [Stream] {
        if let indexPaths = tableView.indexPathsForSelectedRows() {
            return indexPaths.map { self.channels[$0.item] }
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
        observeChannelLoader()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        observer?.dispose()
        observer = nil
    }

    func observeChannelLoader() {
        observer?.dispose()
        observer = channelLoader.signal.observe(next: { event in
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
        case .Category(let category):
            channelLoader.fetchChannels(category)
        case .Search(let query):
            channelLoader.searchChannels(query)
        default:
            break
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
        return channels.count
    }
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(cellReuseIdentifier, forIndexPath: indexPath) as! StreamTableViewCell
        setAccessoryView(cell, indexPath: indexPath)
        let channel = channels[indexPath.item]
        cell.titleLabel.text = channel.title
        if let url = NSURL(string: channel.thumbnails["default"]!) {
            cell.thumbImageView.sd_setImageWithURL(url)
        }
        cell.subtitle1Label.text = channel.description
        if let date = channel.publishedAt {
            cell.subtitle2Label.text = date
        } else {
            cell.subtitle2Label.text = ""
        }
        return cell
    }
}
