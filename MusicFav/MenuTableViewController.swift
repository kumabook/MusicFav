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
import FeedlyKit


class MenuTableViewController: UIViewController, RATreeViewDelegate, RATreeViewDataSource {
    enum Section: Int {
        case General     = 0
        case Feedly      = 1
        case Pocket      = 2
        case Twitter     = 3
        static let count = 4

        var title: String {
            switch self {
            case .General: return "All"
            case .Pocket:  return "Pocket"
            case .Twitter: return "Twitter"
            case .Feedly:  return "Feeds"
            }
        }
        func child(viewController: MenuTableViewController, index: Int) -> AnyObject {
            switch self {
            case .General: return []
            case .Pocket:  return []
            case .Twitter: return []
            case .Feedly:  return viewController.streams[index]
            }
        }
        func numOfChild(viewController: MenuTableViewController) -> Int {
            switch self {
            case .General: return 0
            case .Pocket:  return 0
            case .Twitter: return 0
            case .Feedly:  return viewController.streams.count
            }
        }
    }

    var treeView: RATreeView?
    var streams:  [Stream] = []

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
        self.treeView = RATreeView(frame: self.view.frame)
        self.treeView?.backgroundColor = UIColor.whiteColor()
        self.treeView?.delegate = self;
        self.treeView?.dataSource = self;
        self.treeView?.registerClass(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
        self.view.addSubview(self.treeView!)
        if FeedlyAPIClient.sharedInstance.isLoggedIn {
            self.fetchSubscriptions()
        } else {
            self.fetchTrialFeeds()
        }
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
                    self.streams = subscriptions
                },
                error: {error in
                    println("--failure")
                },
                completed: {
                    self.treeView!.reloadData()
            })
    }

    func fetchTrialFeeds() {
        let client      = FeedlyAPIClient.sharedInstance
        let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        client.fetchFeedsByIds(appDelegate.trialFeeds)
            .deliverOn(MainScheduler())
            .start(
                next: {feeds in
                    self.streams = feeds
                },
                error: {error in
                    println("--failure")
                },
                completed: {
                    self.treeView!.reloadData()
            })
    }
    
    // MARK: - RATreeView data source
    
    func treeView(treeView: RATreeView!, numberOfChildrenOfItem item: AnyObject!) -> Int {
        if item == nil {
            return Section.count
        }
        if let rawValue = item as? Int {
            return Section(rawValue: rawValue)!.numOfChild(self)
        }
        return 0
    }
    
    func treeView(treeView: RATreeView!, cellForItem item: AnyObject!) -> UITableViewCell! {
        let cell = treeView.dequeueReusableCellWithIdentifier("reuseIdentifier") as UITableViewCell
        if item == nil {
            cell.textLabel?.text = "Nothing"
        } else if let rawValue = item as? Int {
            let section = Section(rawValue: rawValue)!
            let num     = section.numOfChild(self)
            if num > 0 {
                cell.textLabel?.text = "\(section.title) (\(section.numOfChild(self)))"
            } else {
                cell.textLabel?.text = "\(section.title)"
            }
        } else if let stream = item as? Stream {
            cell.textLabel?.text = "     " + stream.title
        }
        return cell
    }
    
    func treeView(treeView: RATreeView!, child index: Int, ofItem item: AnyObject!) -> AnyObject! {
        if item == nil {
            return index
        }
        if let rawValue = item as? Int {
            return Section(rawValue: rawValue)!.child(self, index: index)
        }
        return "Nothing"
    }
    
    func treeView(treeView: RATreeView!, didSelectRowForItem item: AnyObject!) {
        if item == nil {
        } else if let rawValue = item as? Int {
            showStream(section:Section(rawValue: rawValue)!)
        } else if let stream = item as? Stream {
            showStream(streamId:stream.id)
        }
    }
    
    func showStream(#section: Section) {
        let appDelegate        = UIApplication.sharedApplication().delegate as AppDelegate
        let mainViewController = appDelegate.miniPlayerViewController?.mainViewController
        switch section {
        case .General:
            mainViewController?.centerPanel = UINavigationController(rootViewController: TimelineTableViewController(streamId: nil))
        case .Pocket:
            return
        case .Twitter:
            return
        case .Feedly:
            return
        }
        mainViewController?.showCenterPanelAnimated(true)
    }
    
    func showStream(#streamId: String?) {
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
