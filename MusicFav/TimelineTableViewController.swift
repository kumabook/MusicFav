//
//  TimelineTableViewController.swift
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

class TimelineTableViewController: UITableViewController {
    var currentIndex = 0
    
    enum State {
        case Normal
        case Fetching
        case Complete
        case Error
    }
    
    let client = FeedlyAPIClient.sharedInstance
    var entries:[Entry] = []
    let timelineTableCellReuseIdentifier = "TimelineTableViewCell"
    var streamId:           String?
    var streamContinuation: String?
    var state       = State.Normal
    var isFetching  = false
    var isStreamEnd =  false
    var indicator:    UIActivityIndicatorView!
    var reloadButton: UIButton!
    var lastUpdated: Int64 = 0
    var unreadOnly = true

    init(streamId: String?) {
        self.streamId = streamId
        super.init(nibName: "TimelineTableViewController", bundle: NSBundle.mainBundle())
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
    }
    
    override func loadView() {
        super.loadView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "TimelineTableViewCell", bundle: nil)
        tableView.registerNib(nib, forCellReuseIdentifier: timelineTableCellReuseIdentifier)

        clearsSelectionOnViewWillAppear = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "playlist"),
            style: UIBarButtonItemStyle.Plain,
            target: self,
            action: "showPlaylist")
        
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
        reloadButton.setTitle("Sorry, network error occured.", forState:UIControlState.Normal)
        reloadButton.frame = CGRectMake(0, 0, tableView.frame.size.width, 44);
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "loadStream", name: "loggedOut", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "loadStream", name: "loggedIn", object: nil)

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action:"fetchLatestEntries", forControlEvents:UIControlEvents.ValueChanged)
        self.updateLastUpdated(nil)
        loadStream()
    }
    
    override func viewWillDisappear(animated: Bool) {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "logout", object: nil)
        super.viewWillDisappear(animated)
    }
    
    func loadStream() {
        let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        appDelegate.miniPlayerViewController?.mainViewController.showCenterPanelAnimated(true)
        
        entries = []
        tableView?.reloadData()
        fetchEntries()
    }
    
    func showPlaylist() {
        let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        appDelegate.miniPlayerViewController?.mainViewController.showRightPanelAnimated(true)
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
    
    func updateLastUpdated(updated: Int64?) {
        if let timestamp = updated {
            self.lastUpdated = timestamp + 1
        } else {
            lastUpdated = Int64(NSDate().timeIntervalSince1970 * 1000)
        }
    }
    
    func fetchLatestEntries() {
        if entries.count == 0 {
            return
        }

        var signal: ColdSignal<PaginatedEntryCollection>
        if let id = streamId {
            signal = client.fetchEntries(streamId:id, newerThan: lastUpdated, unreadOnly: unreadOnly)
        } else {
            self.refreshControl?.beginRefreshing()
            self.refreshControl?.endRefreshing()
            return
        }
        self.refreshControl?.beginRefreshing()
        signal.deliverOn(MainScheduler())
            .start(
                next: { paginatedCollection in
                    let entries = paginatedCollection.items
                    for e in entries {
                        self.entries.insert(e, atIndex: 0)
                    }
                    self.updateLastUpdated(paginatedCollection.updated)
                },
                error: {error in
                    let key = "com.alamofire.serialization.response.error.response"
                    if let dic = error.userInfo as NSDictionary? {
                        if let response:NSHTTPURLResponse = dic[key] as? NSHTTPURLResponse {
                            if response.statusCode == 401 {
                                self.client.clearAllAccount()
                                //TODO: Alert Dialog with login link
                            } else {
                            }
                        } else {
                        }
                    }
                },
                completed: {
                    self.tableView.reloadData()
                    self.refreshControl?.endRefreshing()
            })
    
    }

    func fetchEntries() {
        if state == State.Fetching || state == State.Complete {
            return
        }
        state = State.Fetching
        showIndicator()
        var signal: ColdSignal<PaginatedEntryCollection>
        if let id = streamId {
            signal = client.fetchEntries(streamId:id, continuation: streamContinuation, unreadOnly: unreadOnly)
        } else {
            let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
            let trialFeeds  = appDelegate.trialFeeds
            if currentIndex < trialFeeds.count {
                signal = client.fetchEntries(streamId: trialFeeds[currentIndex], continuation: nil, unreadOnly: unreadOnly)
                currentIndex += 1
            } else {
                self.hideIndicator()
                return
            }
        }
        signal.deliverOn(MainScheduler())
              .start(
                next: {paginatedCollection in
                    let entries = paginatedCollection.items
                    self.entries.extend(entries)
                    self.streamContinuation = paginatedCollection.continuation
                    if paginatedCollection.continuation == nil {
                        self.state = State.Complete
                    } else {
                        self.state = State.Normal
                    }
                    self.updateLastUpdated(paginatedCollection.updated)
                },
                error: {error in
                    let key = "com.alamofire.serialization.response.error.response"
                    if let dic = error.userInfo as NSDictionary? {
                        if let response:NSHTTPURLResponse = dic[key] as? NSHTTPURLResponse {
                            if response.statusCode == 401 {
                                self.client.clearAllAccount()
                                //TODO: Alert Dialog with login link
                            } else {
                                self.state = State.Error
                                self.showReloadButton()
                            }
                        } else {
                            self.state = State.Error
                            self.showReloadButton()
                        }
                    }
                    self.isFetching = false
                },
                completed: {
                    self.hideIndicator()
                    self.tableView.reloadData()
            })
    }

    func markAsRead(indexPath: NSIndexPath) {
        let entry = entries[indexPath.item]
        if self.client.isLoggedIn {
            FeedlyAPIClient.sharedInstance.client.markEntriesAsRead([entry.id], completionHandler: { (req, res, error) -> Void in
                if let e = error { println("Failed to mark as read") }
                else             { println("Succeeded in marking as read") }
            })
        }
        self.entries.removeAtIndex(indexPath.row)
        self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
    }

    func markAsSaved(indexPath: NSIndexPath) {
        let entry = entries[indexPath.item]
        if self.client.isLoggedIn {
            let client = FeedlyAPIClient.sharedInstance.client
            client.markEntriesAsSaved([entry.id], completionHandler: { (req, res, error) -> Void in
                if let e = error { println("Failed to mark as saved") }
                else             { println("Succeeded in marking as saved") }
            })
            client.markEntriesAsRead([entry.id], completionHandler: { (req, res, error) -> Void in
                if let e = error { println("Failed to mark as read") }
                else             { println("Succeeded in marking as read") }
            })

        }
        self.entries.removeAtIndex(indexPath.row)
        self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view data source

    override func scrollViewDidScroll(scrollView: UIScrollView) {
        if tableView.contentOffset.y >= tableView.contentSize.height - tableView.bounds.size.height {
            fetchEntries()
        }
    }
    

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return entries.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let entry = entries[indexPath.row]
        let cell = tableView.dequeueReusableCellWithIdentifier(timelineTableCellReuseIdentifier, forIndexPath:indexPath) as TimelineTableViewCell
        cell.prepareSwipeViews(
            onMarkAsSaved: { (cell) -> Void in
                self.markAsSaved(self.tableView.indexPathForCell(cell)!)
                return
            }, onMarkAsRead: { (cell) -> Void in
                self.markAsRead(self.tableView.indexPathForCell(cell)!)
                return
        })
        cell.titleLabel?.text = entry.title
        if let visual = entry.visual {
            cell.thumbImgView.sd_setImageWithURL(NSURL(string:visual.url), placeholderImage: UIImage(named: "default_thumb"))
        } else {
            cell.thumbImgView.image = UIImage(named: "default_thumb")
        }

        return cell
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let entry = entries[indexPath.item]
        if let alternate = entry.alternate {
            if alternate.count > 0 {
                let vc = EntryWebViewController()
                vc.currentURL = NSURL(string: alternate[0].href)!
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
}
