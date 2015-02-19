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
    var HUD:                 MBProgressHUD!
    var sections:            [Section]                      = []
    var streamsOfCategories: [FeedlyKit.Category: [Stream]] = [:]

    var apiClient:   FeedlyAPIClient  { get { return FeedlyAPIClient.sharedInstance }}
    var appDelegate: AppDelegate      { get { return UIApplication.sharedApplication().delegate as AppDelegate }}


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
        view.backgroundColor = UIColor.whiteColor()
        let f = view.frame
        treeView = RATreeView(frame: CGRect(x: 0, y: 0, width: appDelegate.leftVisibleWidth!, height: f.height))
        treeView?.backgroundColor = UIColor.whiteColor()
        treeView?.delegate = self;
        treeView?.dataSource = self;
        treeView?.registerClass(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
        view.addSubview(self.treeView!)
        HUD = MBProgressHUD.createCompletedHUD(self.view)
        navigationController?.view.addSubview(HUD)

        fetch()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func showPreference() {
        let prefvc = PreferenceViewController()
        presentViewController(UINavigationController(rootViewController:prefvc), animated: true, completion: nil)
    }

    func addStream() {
        let stvc = StreamTableViewController()
        presentViewController(UINavigationController(rootViewController:stvc), animated: true, completion: nil)
    }

    func showStream(#section: Section) {
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
        let mainViewController          = appDelegate.miniPlayerViewController?.mainViewController
        mainViewController?.centerPanel = UINavigationController(rootViewController: TimelineTableViewController(streamId: streamId))
        mainViewController?.showCenterPanelAnimated(true)
    }

    func fetch() {
        sections = [Section.All, Section.Pocket]
        if apiClient.isLoggedIn {
            fetchCategories()
        } else {
            fetchTrialFeeds()
        }
    }

    func fetchCategories() {
        apiClient.fetchCategories()
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
        apiClient.fetchSubscriptions()
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
        apiClient.fetchFeedsByIds(appDelegate.trialFeeds)
            .deliverOn(MainScheduler())
            .start(
                next: {feeds in
                    let samplesCategory = FeedlyKit.Category(id: "feed/musicfav-samples", label: "Sample Feeds")
                    self.sections.append(Section.FeedlyCategory(samplesCategory))
                    self.streamsOfCategories = [samplesCategory:feeds]
                },
                error: {error in
                    println("--failure")
                },
                completed: {
                    self.treeView!.reloadData()
            })
    }

    func unsubscribeTo(subscription: Subscription, index: Int, category: FeedlyKit.Category) {
        MBProgressHUD.showHUDAddedTo(view, animated: true)
        apiClient.client.unsubscribeTo(subscription.id, completionHandler: { (req, res, error) -> Void in
            println(req)
            println(res)
            MBProgressHUD.hideHUDForView(self.view, animated: true)
            if let e = error {
                FeedlyAPIClient.alertController(error: e, handler: { (action) -> Void in })
            } else {
                self.HUD.show(true , duration: 1.0, after: { () -> Void in
                    self.streamsOfCategories[category]!.removeAtIndex(index)
                    self.treeView!.deleteItemsAtIndexes(NSIndexSet(index: index),
                             inParent: self.treeView!.parentForItem(subscription),
                        withAnimation: RATreeViewRowAnimationRight)
                    return
                })
            }
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

    func treeView(treeView: RATreeView!, canEditRowForItem item: AnyObject!) -> Bool {
        if let stream = item as? Stream {
            return true
        }
        return false
    }

    func treeView(treeView: RATreeView!, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowForItem item: AnyObject!) {
        let sectionIndex = treeView.parentForItem(item) as Int
        switch sections[sectionIndex] {
        case .All:
            break
        case .Pocket:
            break
        case .Twitter:
            break
        case .FeedlyCategory(let category):
            if var streams = streamsOfCategories[category] {
                if let subscription = item as? Subscription {
                    var index: Int?
                    for i in 0..<streams.count {
                        if streams[i].id == subscription.id { index = i }
                    }
                    if let i = index {
                        unsubscribeTo(subscription, index: i, category: category)
                    }
                }
            }
        }
    }
}
