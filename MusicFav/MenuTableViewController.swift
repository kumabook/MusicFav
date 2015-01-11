//
//  MenuTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/21/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import LlamaKit


class MenuTableViewController: UITableViewController {
    enum Section: Int {
        case General      = 0
        case FeedlyStream = 1
        static let count  = 2

        var title: String? {
            switch self {
            case .General:      return nil
            case .FeedlyStream: return "Streams"
            }
        }
    }
    
    enum GeneralMenu: Int {
        case Home        = 0

        var title: String {
            switch self {
            case .Home:      return "Home"
            }
        }
    }

    var feedlyStreams                 = []
    var subscriptions: [Subscription] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        let settingsButton  = UIBarButtonItem(image: UIImage(named: "settings"),
                                              style: UIBarButtonItemStyle.Plain,
                                             target: self,
                                             action: "showPreference")
        let addStreamButton = UIBarButtonItem(image: UIImage(named: "add_stream"),
                                              style: UIBarButtonItemStyle.Plain,
                                             target: self,
                                             action: "addStream")
        self.navigationItem.leftBarButtonItems  = [settingsButton, addStreamButton]

        self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
        self.fetchSubscriptions()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func fetchSubscriptions() {
        let client = FeedlyAPIClient.sharedInstance
        client.fetchSubscriptions()
            .deliverOn(MainScheduler())
            .start(
                next: {subscriptions in
                    println(subscriptions)
                    self.subscriptions = subscriptions
                },
                error: {error in
                    println("--failure")
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
        return  Section(rawValue: section)!.title
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .General:
            return 1
        case .FeedlyStream:
            return subscriptions.count
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath) as UITableViewCell
        switch Section(rawValue: indexPath.section)! {
        case .General:
            cell.textLabel?.text = GeneralMenu(rawValue: indexPath.item)?.title
            return cell
        case .FeedlyStream:
            cell.textLabel?.text = subscriptions[indexPath.item].title
            return cell
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .General:
            switch GeneralMenu(rawValue: indexPath.item)! {
            case .Home:
                showStream(nil)
            }
        case .FeedlyStream:
                showStream(subscriptions[indexPath.item].id)
        }
    }
    
    func showStream(streamId: String?) {
        let appDelegate                 = UIApplication.sharedApplication().delegate as AppDelegate
        let mainViewController          = appDelegate.miniPlayerViewController?.mainViewController
        mainViewController?.centerPanel = UINavigationController(rootViewController: TimelineTableViewController(streamId: streamId))
        mainViewController?.showCenterPanelAnimated(true)
    }

    func showPreference() {
        let prefvc = PreferenceViewController()
        presentViewController(UINavigationController(rootViewController:prefvc), animated: true, completion: nil)
    }
    func addStream() {
        let stvc = StreamTableViewController()
        presentViewController(UINavigationController(rootViewController:stvc), animated: true, completion: nil)
    }
}
