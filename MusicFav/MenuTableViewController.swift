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
    enum Section {
        case All
        case FeedlyCategory(FeedlyKit.Category)
        case Pocket
        case Twitter

        var title: String {
            switch self {
            case .All:            return "All"
            case .Pocket:         return "Pocket"
            case .Twitter:        return "Twitter"
            case .FeedlyCategory(let category):
                return category.label
            }
        }
        func child(streamsOfCategories: [FeedlyKit.Category:[Stream]], index: Int) -> AnyObject {
            switch self {
            case .All:            return []
            case .Pocket:         return []
            case .Twitter:        return []
            case .FeedlyCategory(let category):
                if let streams = streamsOfCategories[category] { return streams[index] }
                else                                           { return [] }
            }
        }
        func numOfChild(streamsOfCategories: [FeedlyKit.Category:[Stream]]) -> Int {
            switch self {
            case .All:            return 0
            case .Pocket:         return 0
            case .Twitter:        return 0
            case .FeedlyCategory(let category):
                if let streams = streamsOfCategories[category] { return streams.count }
                else                                           { return 0 }
            }
        }
    }

    var treeView:            RATreeView?
    var sections:            [Section]                      = []
    var streamsOfCategories: [FeedlyKit.Category: [Stream]] = [:]

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
        navigationItem.leftBarButtonItems  = [settingsButton, addStreamButton]
        treeView = RATreeView(frame: self.view.frame)
        treeView?.backgroundColor = UIColor.whiteColor()
        treeView?.delegate = self;
        treeView?.dataSource = self;
        treeView?.registerClass(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
        view.addSubview(self.treeView!)

        fetch()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func fetch() {
        sections = [Section.All, Section.Pocket]
        if FeedlyAPIClient.sharedInstance.isLoggedIn {
            fetchCategories()
        } else {
            fetchTrialFeeds()
        }
    }

    func fetchCategories() {
        FeedlyAPIClient.sharedInstance.fetchCategories()
            .deliverOn(MainScheduler())
            .start(next: {categories in
                for category in categories {
                    self.streamsOfCategories[category] = []
                    self.sections.append(Section.FeedlyCategory(category))
                    println("id \(category.id) label \(category.label)")
                }
            },
            error: {error in
            },
            completed: {
             self.fetchSubscriptions()
        });
    }

    func fetchSubscriptions() {
        let client = FeedlyAPIClient.sharedInstance
        client.fetchSubscriptions()
            .deliverOn(MainScheduler())
            .start(
                next: {subscriptions in
                    for subscription in subscriptions {
                        for c in subscription.categories {
                            self.streamsOfCategories[c]!.append(subscription)
                        }
                    }
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
                    let samplesCategory = FeedlyKit.Category(id: "feed/musicfav-samples", label: "Sample Feeds")
                    self.streamsOfCategories = [samplesCategory:feeds]
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
            return sections.count
        }
        if let index = item as? Int {
            return sections[index].numOfChild(streamsOfCategories)
        }
        return 0
    }
    
    func treeView(treeView: RATreeView!, cellForItem item: AnyObject!) -> UITableViewCell! {
        let cell = treeView.dequeueReusableCellWithIdentifier("reuseIdentifier") as UITableViewCell
        if item == nil {
            cell.textLabel?.text = "Nothing"
        } else if let index = item as? Int {
            let section = sections[index]
            let num     = section.numOfChild(streamsOfCategories)
            if num > 0 {
                cell.textLabel?.text = "\(section.title) (\(section.numOfChild(streamsOfCategories)))"
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
        if let sectionIndex = item as? Int {
            return sections[sectionIndex].child(streamsOfCategories, index: index)
        }
        return "Nothing"
    }
    
    func treeView(treeView: RATreeView!, didSelectRowForItem item: AnyObject!) {
        if item == nil {
        } else if let index = item as? Int {
            showStream(section:sections[index])
        } else if let stream = item as? Stream {
            showStream(streamId:stream.id)
        }
    }

    func showStream(#section: Section) {
        let appDelegate        = UIApplication.sharedApplication().delegate as AppDelegate
        let mainViewController = appDelegate.miniPlayerViewController?.mainViewController
        switch section {
        case .All:
            mainViewController?.centerPanel = UINavigationController(rootViewController: TimelineTableViewController(streamId: nil))
        case .Pocket:
            return
        case .Twitter:
            return
        case .FeedlyCategory(let category):
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
