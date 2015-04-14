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
                return stream.streamTitle
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

    var treeView:         RATreeView?
    var HUD:              MBProgressHUD!
    var sections:         [Section]
    var streamListLoader: StreamListLoader
    var observer:         Disposable?

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

    override init() {
        sections         = []
        streamListLoader = StreamListLoader()
        super.init(nibName: nil, bundle: nil)
    }

    required init(coder aDecoder: NSCoder) {
        sections         = []
        streamListLoader = StreamListLoader()
        super.init(coder: aDecoder)
    }

    deinit {}

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
        observeStreamList()
        refresh()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        observeStreamList()
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        observer?.dispose()
    }

    func showPreference() {
        let prefvc = PreferenceViewController()
        presentViewController(UINavigationController(rootViewController:prefvc), animated: true, completion: nil)
    }

    func addStream() {
        let stvc = StreamTableViewController(streamListLoader: streamListLoader)
        presentViewController(UINavigationController(rootViewController:stvc), animated: true, completion: nil)
    }

    func showStream(#section: Section) {
        let mainViewController = appDelegate.miniPlayerViewController?.mainViewController
        switch section {
        case .GlobalResource(let stream):
            mainViewController?.centerPanel = UINavigationController(rootViewController: StreamPageMenuController(stream: stream))
        case .Pocket:  return
        case .Twitter: return
        case .FeedlyCategory(let category): return
        }
        mainViewController?.showCenterPanelAnimated(true)
    }

    func showStream(#stream: Stream) {
        let mainViewController          = appDelegate.miniPlayerViewController?.mainViewController
        mainViewController?.centerPanel = UINavigationController(rootViewController: StreamPageMenuController(stream: stream))
        mainViewController?.showCenterPanelAnimated(true)
    }

    func observeStreamList() {
        observer?.dispose()
        observer = streamListLoader.signal.observe({ event in
            switch event {
            case .StartLoading:
                self.refreshControl?.beginRefreshing()
            case .CompleteLoading:
                let categories = self.streamListLoader.streamListOfCategory.keys
                self.sections  = self.defaultSections()
                self.sections.extend(categories.map({ Section.FeedlyCategory($0) }))
                self.refreshControl?.endRefreshing()
                self.treeView?.reloadData()
            case .FailToLoad(let e):
                FeedlyAPIClient.alertController(error: e, handler: { (action) -> Void in })
                self.refreshControl?.endRefreshing()
            case .StartUpdating:
                MBProgressHUD.hideHUDForView(self.view, animated: true)
            case .FailToUpdate(let e):
                FeedlyAPIClient.alertController(error: e, handler: { (action) -> Void in })
            case .CreateAt(let subscription):
                self.HUD.show(true , duration: 1.0, after: { () -> Void in
                    self.refresh()
                })
            case .RemoveAt(let index, let subscription, let category):
                self.HUD.show(true , duration: 1.0, after: { () -> Void in
                    self.treeView!.deleteItemsAtIndexes(NSIndexSet(index: index),
                        inParent: self.treeView!.parentForItem(subscription),
                        withAnimation: RATreeViewRowAnimationRight)
                })
            }
        })
    }

    func refresh() {
        streamListLoader.refresh()
    }

    func unsubscribeTo(subscription: Subscription, index: Int, category: FeedlyKit.Category) {
        streamListLoader.unsubscribeTo(subscription, index: index, category: category)
    }

    // MARK: - RATreeView data source
    
    func treeView(treeView: RATreeView!, numberOfChildrenOfItem item: AnyObject!) -> Int {
        if item == nil {
            return sections.count
        }
        if let index = item as? Int {
            return sections[index].numOfChild(streamListLoader.streamListOfCategory)
        }
        return 0
    }
    
    func treeView(treeView: RATreeView!, cellForItem item: AnyObject!) -> UITableViewCell! {
        let cell = treeView.dequeueReusableCellWithIdentifier("reuseIdentifier") as UITableViewCell
        if item == nil {
            cell.textLabel?.text = "Nothing"
        } else if let index = item as? Int {
            let section = sections[index]
            let num     = section.numOfChild(streamListLoader.streamListOfCategory)
            if num > 0 {
                cell.textLabel?.text = "\(section.title) (\(section.numOfChild(streamListLoader.streamListOfCategory)))"
            } else {
                cell.textLabel?.text = "\(section.title)"
            }
        } else if let stream = item as? Stream {
            cell.textLabel?.text = "     " + stream.streamTitle
        }
        return cell
    }
    
    func treeView(treeView: RATreeView!, child index: Int, ofItem item: AnyObject!) -> AnyObject! {
        if item == nil {
            return index
        }
        if let sectionIndex = item as? Int {
            return sections[sectionIndex].child(streamListLoader.streamListOfCategory, index: index)
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
            if var streams = streamListLoader.streamListOfCategory[category] {
                if let subscription = item as? Subscription {
                    var index: Int?
                    for i in 0..<streams.count {
                        if streams[i].streamId == subscription.id { index = i }
                    }
                    if let i = index {
                        unsubscribeTo(subscription, index: i, category: category)
                    }
                }
            }
        }
    }
}
