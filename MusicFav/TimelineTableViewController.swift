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

class TimelineTableViewController: UITableViewController {
    
    let trialFeeds = [
        "feed/http://spincoaster.com/feed",
        "feed/http://matome.naver.jp/feed/topic/1Hinb"
    ]
    var currentIndex = 0
    
    enum State {
        case Normal
        case Fetching
        case Complete
        case Error
    }
    
    let client = FeedlyAPIClient.sharedInstance
    var entries:[Entry] = []
    let tableCellReuseIdentifier = "timelineTableViewCell"
    var streamId:           String?
    var streamContinuation: String?
    var state       = State.Normal
    var isFetching  = false
    var isStreamEnd =  false
    var indicator:    UIActivityIndicatorView!
    var reloadButton: UIButton!
    var lastUpdated: Int64 = 0

    init(streamId: String?) {
        self.streamId = streamId
        super.init(nibName: "TimelineTableViewController", bundle: NSBundle.mainBundle())
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
    }
    
    override func loadView() {
        super.loadView()
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "playlist"),
                                                            style: UIBarButtonItemStyle.Plain,
                                                           target: self,
                                                           action: "showPlaylist")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "TimelineTableViewCell", bundle: nil)
        tableView.registerNib(nib, forCellReuseIdentifier: tableCellReuseIdentifier)
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
        reloadButton.setTitle("Sorry, network error occured.", forState:UIControlState.Normal)
        reloadButton.frame = CGRectMake(0, 0, tableView.frame.size.width, 44);
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "initialize", name: "loggedOut", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "initialize", name: "loggedIn", object: nil)
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
        if let account = client.account {
            fetchEntries()
        } else {
            appDelegate.miniPlayerViewController?.showOAuthViewController()
        }
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

        var signal: ColdSignal<JSON>
        if let id = streamId {
            signal = client.fetchEntries(streamId:id, newerThan: lastUpdated)
        } else if FeedlyAPIClient.sharedInstance.isLoggedIn {
            signal = client.fetchAllEntries(newerThan: lastUpdated)
        } else {
            return
        }
        self.refreshControl?.beginRefreshing()
        signal.deliverOn(MainScheduler())
            .start(
                next: {json in
                    let entries = json["items"].array!.map({ Entry(json: $0)})
                    for e in entries {
                        self.entries.insert(e, atIndex: 0)
                    }
                    self.updateLastUpdated(json["update"].int64?)
                },
                error: {error in
                    let key = "com.alamofire.serialization.response.error.response"
                    if let dic = error.userInfo as NSDictionary? {
                        if let response:NSHTTPURLResponse = dic[key] as? NSHTTPURLResponse {
                            if response.statusCode == 401 {
                                self.client.clearAllAccount()
//                                self.loginWithOAuth()
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
        var signal: ColdSignal<JSON>
        if let id = streamId {
            signal = client.fetchEntries(streamId:id, continuation: streamContinuation)
        } else if FeedlyAPIClient.sharedInstance.isLoggedIn {
            signal = client.fetchAllEntries(continuation: streamContinuation)
        } else {
            if currentIndex < trialFeeds.count {
                signal = client.fetchEntries(streamId: trialFeeds[currentIndex], continuation: nil)
                currentIndex += 1
            } else {
                self.hideIndicator()
                return
            }
        }
        signal.deliverOn(MainScheduler())
              .start(
                next: {json in
                    let entries = json["items"].array!.map({ Entry(json: $0)})
                    self.entries.extend(entries)
                    self.streamContinuation = json["continuation"].string?
                    if json["continuation"].string? == nil {
                        self.state = State.Complete
                    } else {
                        self.state = State.Normal
                    }
                    self.updateLastUpdated(json["update"].int64?)
                },
                error: {error in
                    let key = "com.alamofire.serialization.response.error.response"
                    if let dic = error.userInfo as NSDictionary? {
                        if let response:NSHTTPURLResponse = dic[key] as? NSHTTPURLResponse {
                            if response.statusCode == 401 {
                                self.client.clearAllAccount()
//                                self.loginWithOAuth()
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
        let cell = tableView.dequeueReusableCellWithIdentifier(tableCellReuseIdentifier, forIndexPath: indexPath) as TimelineTableViewCell

        let entry = entries[indexPath.item]
        cell.titleLabel.text = entry.title
        if let url = entry.visualUrl {
            cell.thumbImgView.sd_setImageWithURL(NSURL(string:url))
        } else {
            cell.thumbImgView.image = nil
        }

        return cell
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        let markAsRead = UITableViewRowAction(style: .Default, title: "Mark as Read") {
            (action, indexPath) in
            let entry = self.entries.removeAtIndex(indexPath.item)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }
        
        markAsRead.backgroundColor = UIColor.redColor()
        
        return [markAsRead]
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let entry = entries[indexPath.item]
        let vc    = EntryWebViewController()
        if let urlString = entry.alternate {
            vc.currentURL = NSURL(string: urlString)!
        }
        navigationController?.pushViewController(vc, animated: true)
    }
}
