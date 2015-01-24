//
//  StreamTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 1/3/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import LlamaKit
import FeedlyKit

class StreamTableViewController: UITableViewController {

    enum Section: Int {
        case SearchResult        = 0
        case FeedsWithMusicTopic = 1
        static let count         = 2
        var title: String? {
            get {
                switch self {
                case .FeedsWithMusicTopic:
                    return "Popular feeds"
                default:
                    return nil
                }
            }
        }
    }
    let client = FeedlyAPIClient.sharedInstance
    var isLoggedIn: Bool {
        get {
            return client.account != nil
        }
    }
    var subscriptions:     [Subscription] = []
    var feedsOfMusicTopic: [Feed]         = []

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
        if isLoggedIn {
            fetchSubscriptions()
        }
        fetchFeedsOfMusicTopic()
    }

    override func loadView() {
        super.loadView()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title:"close",
                                                                style: UIBarButtonItemStyle.Plain,
                                                               target: self,
                                                               action: "close")
        self.navigationItem.title = "Import to MusicFav"
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func fetchSubscriptions() {
        client.fetchSubscriptions()
            .deliverOn(MainScheduler())
            .start(
                next: {subscriptions in
                    println(subscriptions)
                    self.subscriptions = subscriptions
                },
                error: {error in
                    self.alertNetworkFailure()
                },
                completed: {
                    self.tableView.reloadData()
                    if let sub = self.subscriptions.first as Subscription? {
                    }
            })
    }
    
    func fetchFeedsOfMusicTopic() {
        let account = client.account
        client.fetchFeedsByTopic("music")
            .deliverOn(MainScheduler())
            .start(
                next: {feeds in
                    println(feeds)
                    self.feedsOfMusicTopic = feeds
                },
                error: {error in
                    self.alertNetworkFailure()
                },
                completed: {
                    self.tableView.reloadData()
            })
    }
    
    
    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return Section.count
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (Section(rawValue: section)!) {
        case .SearchResult:
            return 0
        case .FeedsWithMusicTopic:
            return feedsOfMusicTopic.count
        }
    }


    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath) as UITableViewCell
        switch Section(rawValue: indexPath.section)! {
        case .FeedsWithMusicTopic:
            cell.textLabel?.text = feedsOfMusicTopic[indexPath.item].title
        default:
            break
        }
        return cell
    }
    
    func close() {
        self.navigationController?.dismissViewControllerAnimated(true, nil)
    }
    
    func alertNetworkFailure() {
        let ac = UIAlertController(title: "Network error", message: "Network error occured", preferredStyle: UIAlertControllerStyle.Alert)
        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default) { (action) in
        }
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return NO if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return NO if you do not want the item to be re-orderable.
        return true
    }
    */
}
