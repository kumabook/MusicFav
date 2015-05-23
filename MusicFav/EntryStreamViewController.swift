//
//  EntryStreamViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/21/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import LlamaKit
import SwiftyJSON
import FeedlyKit
import PageMenu

class EntryStreamViewController: UITableViewController {
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    let cellHeight: CGFloat = 120
    let entryStreamTableCellReuseIdentifier = "EntryStreamTableViewCell"

    let streamLoader: StreamLoader!
    var observer:     Disposable?
    var indicator:    UIActivityIndicatorView!
    var reloadButton: UIButton!

    var feedlyClient: CloudAPIClient { return streamLoader.feedlyClient }

    init(streamLoader: StreamLoader) {
        self.streamLoader = streamLoader
        super.init(nibName: nil, bundle: nil)
    }

    override init(style: UITableViewStyle) {
        self.streamLoader = StreamLoader(stream: DummyStream())
        super.init(style: style)
    }

    required init(coder aDecoder: NSCoder) {
        self.streamLoader = StreamLoader(stream: DummyStream())
        super.init(coder:aDecoder)
    }

    deinit {
        observer?.dispose()
    }

    override func loadView() {
        super.loadView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.accessibilityIdentifier = AccessibilityLabel.EntryStreamTableView.s
        let nib = UINib(nibName: "EntryStreamTableViewCell", bundle: nil)
        tableView.registerNib(nib, forCellReuseIdentifier: entryStreamTableCellReuseIdentifier)

        clearsSelectionOnViewWillAppear = true

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
        reloadButton.addTarget(self, action:"fetchEntries", forControlEvents:UIControlEvents.TouchUpInside)
        reloadButton.setTitle("Sorry, network error occured.".localize(), forState:UIControlState.Normal)
        reloadButton.frame = CGRectMake(0, 0, tableView.frame.size.width, 44);

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action:"fetchLatestEntries", forControlEvents:UIControlEvents.ValueChanged)
        // workaround because tableView height is too long
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1)), dispatch_get_main_queue()) {
            if let pageMenu = self.parentViewController as? CAPSPageMenu {
                let f = self.view.frame
                self.view.frame = CGRect(x: f.origin.x, y: f.origin.y, width: f.width, height: f.height - pageMenu.menuHeight)
            }
            return
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
        let streamPageMenu: StreamPageMenuController? = appDelegate.miniPlayerViewController?.streamPageMenuController
        if let other = streamPageMenu?.playlistStreamViewController {
            if other.tableView != nil {
                tableView.contentOffset = other.tableView.contentOffset
            }
        }
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        observeStreamLoader()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        observer?.dispose()
        observer = nil
    }

    func observeStreamLoader() {
        observer?.dispose()
        observer = streamLoader.signal.observe(next: { event in
            switch event {
            case .StartLoadingLatest:
                self.refreshControl?.beginRefreshing()
            case .CompleteLoadingLatest:
                self.tableView.reloadData()
                self.refreshControl?.endRefreshing()
            case .StartLoadingNext:
                self.showIndicator()
            case .CompleteLoadingNext:
                self.hideIndicator()
                self.tableView.reloadData()
            case .FailToLoadNext:
                self.showReloadButton()
            case .CompleteLoadingPlaylist(let playlist, let entry):
                if let i = find(self.streamLoader.entries, entry) {
                    if i < self.tableView.numberOfRowsInSection(0) {
                        let index = NSIndexPath(forItem: i, inSection: 0)
                        self.tableView.reloadRowsAtIndexPaths([index], withRowAnimation: UITableViewRowAnimation.None)
                    }
                }
            case .RemoveAt(let index):
                let indexPath = NSIndexPath(forItem: index, inSection: 0)
                self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            }
        })

        tableView?.reloadData()
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        appDelegate.miniPlayerViewController?.mainViewController.showCenterPanelAnimated(true)
    }

    func showPlaylist() {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        appDelegate.miniPlayerViewController?.mainViewController.showRightPanelAnimated(true)
    }

    func fetchEntries() {
        streamLoader.fetchEntries()
    }

    func fetchLatestEntries() {
        streamLoader.fetchLatestEntries()
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

    func markAsRead(indexPath: NSIndexPath) {
        streamLoader.markAsRead(indexPath.item)
    }

    func markAsUnread(indexPath: NSIndexPath) {
        streamLoader.markAsUnread(indexPath.item)
    }

    func markAsUnsaved(indexPath: NSIndexPath) {
        streamLoader.markAsUnsaved(indexPath.item)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func scrollViewDidScroll(scrollView: UIScrollView) {
        if tableView.contentOffset.y >= tableView.contentSize.height - tableView.bounds.size.height {
            streamLoader.fetchEntries()
        }
    }

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return streamLoader.entries.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let entry = streamLoader.entries[indexPath.row]
        let cell = tableView.dequeueReusableCellWithIdentifier(entryStreamTableCellReuseIdentifier, forIndexPath:indexPath) as! EntryStreamTableViewCell
        let markAs = streamLoader.removeMark
        weak var _self = self
        cell.prepareSwipeViews(markAs, onSwipe: { (cell) -> Void in
            if _self == nil { return }
            let __self = _self!
            if !__self.feedlyClient.isLoggedIn {
                let title   = "Notice".localize()
                let message = "You can mark article as read after login.".localize() + "Please login from the menu of the top of left panel.".localize()
                UIAlertController.show(self, title: title, message: message, handler: { (action) in })
                cell.swipeToOriginWithCompletion({})
            } else {
                switch markAs {
                case .Read:
                    __self.markAsRead(__self.tableView.indexPathForCell(cell)!)
                case .Unread:
                    __self.markAsUnread(__self.tableView.indexPathForCell(cell)!)
                case .Unsave:
                    __self.markAsUnsaved(__self.tableView.indexPathForCell(cell)!)
                }
            }
        })
        cell.titleLabel?.text = entry.title
        if let originTitle = entry.origin?.title {
            cell.originTitleLabel?.text  = originTitle
        }
        cell.dateLabel?.text  = entry.passedTime

        if let url = entry.thumbnailURL {
            cell.thumbImgView.sd_setImageWithURL(url, placeholderImage: UIImage(named: "default_thumb"))
        } else {
            cell.thumbImgView.image = UIImage(named: "default_thumb")
        }

        return cell
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let entry = streamLoader.entries[indexPath.item]
        if let nav = parentViewController?.parentViewController?.navigationController {
            Logger.sendUIActionEvent(self, action: "didSelectRowAtIndexPath", label: String(indexPath.item))
            let vc = EntryWebViewController(entry: entry, playlist: streamLoader.playlistsOfEntry[entry])
            appDelegate.selectedPlaylist = vc.playlist
            appDelegate.miniPlayerViewController?.playlistTableViewController.updateNavbar()
            appDelegate.miniPlayerViewController?.playlistTableViewController.tableView.reloadData()
            nav.pushViewController(vc, animated: true)
        }
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return self.cellHeight
    }
}
