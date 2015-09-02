//
//  StreamTreeViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/21/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import FeedlyKit
import MusicFeeder
import RATreeView
import MBProgressHUD
import SoundCloudKit

class StreamTreeViewController: UIViewController, RATreeViewDelegate, RATreeViewDataSource {
    enum Section {
        case GlobalResource(Stream)
        case FeedlyCategory(FeedlyKit.Category)
        case UncategorizedSubscription(Subscription)
        case SoundCloud
        case Pocket
        case Twitter

        var title: String {
            switch self {
            case .GlobalResource(let stream):                  return stream.streamTitle.localize()
            case .SoundCloud:                                  return "SoundCloud"
            case .Pocket:                                      return "Pocket"
            case .Twitter:                                     return "Twitter"
            case .FeedlyCategory(let category):                return category.label
            case .UncategorizedSubscription(let subscription): return subscription.streamTitle
            }
        }
        func setThumbImage(view: UIImageView?) {
            switch self {
            case .GlobalResource(let stream):
                switch stream.streamTitle {
                case "All":
                    view?.image = UIImage(named: "home")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
                case "Saved":
                    view?.image = UIImage(named: "fav_entry")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
                case "Read":
                    view?.image = UIImage(named: "checkmark")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
                default: break
                }
            case .SoundCloud:
                view?.image = UIImage(named: "soundcloud_icon")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
            case .Pocket: break
            case .Twitter: break
            case .FeedlyCategory(let category):
                view?.image = UIImage(named: "folder")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
            case .UncategorizedSubscription(let subscription):
                view?.sd_setImageWithURL(subscription.thumbnailURL, placeholderImage: UIImage(named: "default_thumb"))
            }
        }
        func child(streamListDic: [FeedlyKit.Category:[Stream]], index: Int) -> AnyObject {
            switch self {
            case .GlobalResource: return []
            case .SoundCloud:     return []
            case .Pocket:         return []
            case .Twitter:        return []
            case .FeedlyCategory(let category):
                if let streams = streamListDic[category] { return streams[index] }
                else                                     { return [] }
            case .UncategorizedSubscription(let subscription): return []
            }
        }
        func numOfChild(streamListDic: [FeedlyKit.Category:[Stream]]) -> Int {
            switch self {
            case .GlobalResource: return 0
            case .SoundCloud:     return 0
            case .Pocket:         return 0
            case .Twitter:        return 0
            case .FeedlyCategory(let category):
                if let streams = streamListDic[category] { return streams.count }
                else                                     { return 0 }
            case .UncategorizedSubscription(let subscription): return 0
            }
        }
    }

    var treeView:         RATreeView?
    var sections:         [Section]
    var streamListLoader: StreamListLoader
    var observer:         Disposable?

    var apiClient:   CloudAPIClient    { return CloudAPIClient.sharedInstance }
    var appDelegate: AppDelegate       { return UIApplication.sharedApplication().delegate as! AppDelegate }
    var root:        UIViewController? { return view.window?.rootViewController }

    var refreshControl: UIRefreshControl?

    func defaultSections() -> [Section] {
        if let userId = FeedlyAPI.profile?.id {
            var sections: [Section] = [.GlobalResource(FeedlyKit.Category.All(userId)),
                                       .GlobalResource(FeedlyKit.Tag.Saved(userId)),
                                       .GlobalResource(FeedlyKit.Tag.Read(userId))]
            if SoundCloudKit.APIClient.isLoggedIn { sections.append(.SoundCloud) }
            return sections
        }
        else {
            return []
        }
    }

    init() {
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
        treeView = RATreeView(frame: CGRect(x: 0, y: 0, width: appDelegate.leftVisibleWidth!, height: view.frame.height))
        treeView?.backgroundColor = UIColor.whiteColor()
        treeView?.delegate = self
        treeView?.dataSource = self
        treeView?.registerClass(StreamTreeViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
        view.addSubview(self.treeView!)

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action:"refresh", forControlEvents:UIControlEvents.ValueChanged)
        treeView?.addResreshControl(refreshControl!)

        refresh()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        treeView!.frame = CGRect(x: 0, y: 0, width: appDelegate.leftVisibleWidth!, height: view.frame.height)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
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
        root?.presentViewController(UINavigationController(rootViewController:prefvc), animated: true, completion: nil)
    }

    func addStream() {
        let admvc = AddStreamMenuViewController(streamListLoader: streamListLoader)
        root?.presentViewController(UINavigationController(rootViewController:admvc), animated: true, completion: nil)
    }

    func showStream(#section: Section) {
        switch section {
        case .GlobalResource(let stream):
            showStream(stream: stream)
        case .SoundCloud:
            showSoundCloudActivities()
        case .Pocket:  return
        case .Twitter: return
        case .FeedlyCategory(let category): return
        case .UncategorizedSubscription(let subscription):
            showStream(stream: subscription)
        }
    }

    func showStream(#stream: Stream) {
        appDelegate.miniPlayerViewController?.setStreamPageMenu(stream)
    }

    func showSoundCloudActivities() {
        let vc = SoundCloudActivityTableViewController()
        appDelegate.miniPlayerViewController?.setCenterViewController(vc)
    }

    func observeStreamList() {
        observer?.dispose()
        observer = streamListLoader.signal.observe(next: { event in
            switch event {
            case .StartLoading:
                self.refreshControl?.beginRefreshing()
            case .CompleteLoading:
                let categories = self.streamListLoader.categories.filter({
                    $0 != self.streamListLoader.uncategorized
                })
                self.sections  = self.defaultSections()
                self.sections.extend(categories.map({ Section.FeedlyCategory($0) }))
                self.sections.extend(self.streamListLoader.uncategorizedStreams.map {
                    if let subscription = $0 as? Subscription {
                        return Section.UncategorizedSubscription(subscription)
                    } else if let feed = $0 as? Feed {
                        return Section.UncategorizedSubscription(Subscription(feed: feed, categories: []))
                    } else {
                        return Section.UncategorizedSubscription(Subscription(id: "Unknown", title: "Unknown", categories: []) )
                    }
                })
                self.refreshControl?.endRefreshing()
                self.treeView?.reloadData()
            case .FailToLoad(let e):
                CloudAPIClient.alertController(error: e, handler: { (action) -> Void in })
                self.refreshControl?.endRefreshing()
            case .StartUpdating:
                MBProgressHUD.showHUDAddedTo(self.view, animated: true)
            case .FailToUpdate(let e):
                MBProgressHUD.hideHUDForView(self.view, animated: true)
                CloudAPIClient.alertController(error: e, handler: { (action) -> Void in })
            case .RemoveAt(let index, let subscription, let category):
                MBProgressHUD.hideHUDForView(self.view, animated: true)
                MBProgressHUD.showCompletedHUDForView(self.navigationController!.view, animated: true, duration: 1.0, after: {
                    let l = self.streamListLoader
                    if category == l.uncategorized {
                        let i = self.indexOfUncategorizedSubscription(subscription)
                        self.treeView!.deleteItemsAtIndexes(NSIndexSet(index: i),
                                 inParent: nil,
                            withAnimation: RATreeViewRowAnimationRight)
                        self.sections.removeAtIndex(i)
                        self.treeView!.reloadData()
                    } else {
                        self.treeView!.deleteItemsAtIndexes(NSIndexSet(index: index),
                                 inParent: self.treeView!.parentForItem(subscription),
                            withAnimation: RATreeViewRowAnimationRight)
                        self.treeView!.reloadRowsForItems([self.indexOfCategory(category)],
                                                withRowAnimation: RATreeViewRowAnimationRight)
                    }
                })
            }
        })
    }

    func indexOfCategory(category: FeedlyKit.Category) -> Int {
        var i = 0
        for section in sections {
            switch section {
            case .FeedlyCategory(let c): if c == category { return i }
            default:                     break
            }
            i++
        }
        return i
    }

    func indexOfUncategorizedSubscription(subscription: Subscription) -> Int {
        var i = 0
        for section in sections {
            switch section {
            case .UncategorizedSubscription(let sub): if sub == subscription { return i }
            default:                                  break
            }
            i++
        }
        return i
    }

    func refresh() {
        observer?.dispose()
        observeStreamList()
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

    func treeView(treeView: RATreeView!, indentationLevelForRowForItem item: AnyObject!) -> Int {
        if let stream = item as? Stream {
            return 1
        } else {
            return 0
        }
    }

    func treeView(treeView: RATreeView!, shouldIndentWhileEditingRowForItem item: AnyObject!) -> Bool {
        return true
    }

    func treeView(treeView: RATreeView!, cellForItem item: AnyObject!) -> UITableViewCell! {
        let cell = treeView.dequeueReusableCellWithIdentifier("reuseIdentifier") as! StreamTreeViewCell
        if let i = self.treeView?.levelForCellForItem(item) { cell.indent = i }
        if item == nil {
            cell.textLabel?.text = "Nothing"
        } else if let index = item as? Int {
            let section = sections[index]
            section.setThumbImage(cell.imageView)
            let num = section.numOfChild(streamListLoader.streamListOfCategory)
            if num > 0 {
                cell.textLabel?.text = "\(section.title) (\(section.numOfChild(streamListLoader.streamListOfCategory)))"
            } else {
                cell.textLabel?.text = "\(section.title)"
            }
        } else if let stream = item as? Stream {
            cell.textLabel?.text = stream.streamTitle
            if let subscription = stream as? Subscription {
                cell.imageView?.sd_setImageWithURL(subscription.thumbnailURL, placeholderImage: UIImage(named: "default_thumb"))
            }
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
        Logger.sendUIActionEvent(self, action: "didSelectRowForItem", label: "")
        if item == nil {
        } else if let index = item as? Int {
            showStream(section:sections[index])
        } else if let stream = item as? Stream {
            showStream(stream:stream)
        }
    }

    func treeView(treeView: RATreeView!, canEditRowForItem item: AnyObject!) -> Bool {
        if let index = item as? Int {
            switch sections[index] {
            case Section.UncategorizedSubscription: return true
            default:                                return false
            }
        } else if let stream = item as? Stream {
            return true
        }
        return false
    }

    func treeView(treeView: RATreeView!, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowForItem item: AnyObject!) {
        Logger.sendUIActionEvent(self, action: "commitEditingStyle", label: "")
        if let index = item as? Int {
            switch sections[index] {
            case Section.UncategorizedSubscription(let subscription):
                let uncategorized = streamListLoader.uncategorized
                if let i = find(streamListLoader.uncategorizedStreams, subscription) {
                    unsubscribeTo(subscription, index: i, category: uncategorized)
                }
            default: break
            }
        } else if let stream = item as? Stream {
            let sectionIndex = treeView.parentForItem(item) as! Int
            switch sections[sectionIndex] {
            case .FeedlyCategory(let category):
                if var streams = streamListLoader.streamListOfCategory[category] {
                    var stream = item as! Stream
                    if let i = find(streams, stream) {
                        if let subscription = item as? Subscription {
                            unsubscribeTo(subscription, index: i, category: category)
                        }
                    }
                }
            default: break
            }
        }
    }
}
