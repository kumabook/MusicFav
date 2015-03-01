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
import RATreeView
import MBProgressHUD

class MenuTableViewController: UIViewController, RATreeViewDelegate, RATreeViewDataSource {
    enum Section {
        case GlobalResource(Stream)
        case FeedlyCategory(FeedlyKit.Category)
        case Pocket
        case Twitter

        var title: String {
            switch self {
            case .GlobalResource(let stream):
                return stream.title
            case .Pocket:  return "Pocket"
            case .Twitter: return "Twitter"
            case .FeedlyCategory(let category):
                return category.label
            }
        }
        func child(streamListDic: [FeedlyKit.Category:[Stream]], index: Int) -> AnyObject {
            switch self {
            case .GlobalResource: return []
            case .Pocket:         return []
            case .Twitter:        return []
            case .FeedlyCategory(let category):
                if let streams = streamListDic[category] { return streams[index] }
                else                                           { return [] }
            }
        }
        func numOfChild(streamListDic: [FeedlyKit.Category:[Stream]]) -> Int {
            switch self {
            case .GlobalResource: return 0
            case .Pocket:         return 0
            case .Twitter:        return 0
            case .FeedlyCategory(let category):
                if let streams = streamListDic[category] { return streams.count }
                else                                           { return 0 }
            }
        }
    }

    var treeView:      RATreeView?
    var HUD:           MBProgressHUD!
    var sections:      [Section]                      = []
    var streamListDic: [FeedlyKit.Category: [Stream]] = [:]

    var apiClient:   FeedlyAPIClient  { get { return FeedlyAPIClient.sharedInstance }}
    var appDelegate: AppDelegate      { get { return UIApplication.sharedApplication().delegate as AppDelegate }}

    var refreshControl: UIRefreshControl?

    func defaultSections() -> [Section] {
        if let userId = apiClient.profile?.id {
            return [.GlobalResource(FeedlyKit.Category.All(userId)),
                    .GlobalResource(FeedlyKit.Tag.Saved(userId)),
                    .GlobalResource(FeedlyKit.Tag.Read(userId)),
                    .GlobalResource(FeedlyKit.Category.Uncategorized(userId))]
        }
        else {
            return []
        }
    }

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

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action:"refresh", forControlEvents:UIControlEvents.ValueChanged)
        treeView?.addResreshControl(refreshControl!)

        HUD = MBProgressHUD.createCompletedHUD(self.view)
        navigationController?.view.addSubview(HUD)

        refresh()
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
        case .GlobalResource(let stream):
            mainViewController?.centerPanel = UINavigationController(rootViewController: TimelineTableViewController(stream: stream))
        case .Pocket:  return
        case .Twitter: return
        case .FeedlyCategory(let category): return
        }
        mainViewController?.showCenterPanelAnimated(true)
    }

    func showStream(#stream: Stream?) {
        let mainViewController          = appDelegate.miniPlayerViewController?.mainViewController
        mainViewController?.centerPanel = UINavigationController(rootViewController: TimelineTableViewController(stream: stream))
        mainViewController?.showCenterPanelAnimated(true)
    }

    func refresh() {
        sections = defaultSections()
        self.refreshControl?.beginRefreshing()
        fetch().deliverOn(MainScheduler()).start(
            next: { (_sections, _streamListDic) in
                self.sections.extend(_sections)
                self.refreshControl?.endRefreshing();
                self.streamListDic = _streamListDic;  return
            }, error: { error in
                self.refreshControl?.endRefreshing(); return
            }, completed: {
                self.treeView?.reloadData();          return
        })
    }

    func fetch() -> ColdSignal<([Section], [FeedlyKit.Category: [Stream]])> {
        if apiClient.isLoggedIn {
            return fetchSubscriptions()
        } else {
            return fetchTrialFeeds()
        }
    }

    func fetchSubscriptions() -> ColdSignal<([Section], [FeedlyKit.Category: [Stream]])> {
        return apiClient.fetchCategories().merge({categoryListSignal in
            self.apiClient.fetchSubscriptions().map({ subscriptions in
                return categoryListSignal.map({ categories in
                    let sections = categories.map({ Section.FeedlyCategory($0) })
                    var streamListDic: [FeedlyKit.Category: [Stream]] = [:]
                    for category in categories {
                        streamListDic[category] = [] as [Stream]
                    }
                    for subscription in subscriptions {
                        for category in subscription.categories {
                            streamListDic[category]!.append(subscription)
                        }
                    }
                    return (sections, streamListDic)
                })
            })
        })
    }

    func fetchTrialFeeds() -> ColdSignal<([Section], [FeedlyKit.Category: [Stream]])> {
        return apiClient.fetchFeedsByIds(self.appDelegate.sampleFeeds).map({feeds in
            let samplesCategory = FeedlyKit.Category(id: "feed/musicfav-samples",
                                                  label: "Sample Feeds")
            let section = Section.FeedlyCategory(samplesCategory)
            let streamListDic = [samplesCategory:feeds] as [FeedlyKit.Category: [Stream]]
            return ([section], streamListDic)
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
                    self.streamListDic[category]!.removeAtIndex(index)
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
            return sections[index].numOfChild(streamListDic)
        }
        return 0
    }
    
    func treeView(treeView: RATreeView!, cellForItem item: AnyObject!) -> UITableViewCell! {
        let cell = treeView.dequeueReusableCellWithIdentifier("reuseIdentifier") as UITableViewCell
        if item == nil {
            cell.textLabel?.text = "Nothing"
        } else if let index = item as? Int {
            let section = sections[index]
            let num     = section.numOfChild(streamListDic)
            if num > 0 {
                cell.textLabel?.text = "\(section.title) (\(section.numOfChild(streamListDic)))"
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
            return sections[sectionIndex].child(streamListDic, index: index)
        }
        return "Nothing"
    }

    func treeView(treeView: RATreeView!, didSelectRowForItem item: AnyObject!) {
        if item == nil {
        } else if let index = item as? Int {
            showStream(section:sections[index])
        } else if let stream = item as? Stream {
            showStream(stream:stream)
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
        case .GlobalResource: break
        case .Pocket:         break
        case .Twitter:        break
        case .FeedlyCategory(let category):
            if var streams = streamListDic[category] {
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
