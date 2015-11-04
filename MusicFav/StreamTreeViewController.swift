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
        case Saved
        case History
        case YouTube
        case SoundCloud
        case Pocket
        case Twitter

        var title: String {
            switch self {
            case .GlobalResource(let stream):                  return stream.streamTitle.localize()
            case .Saved:                                       return "Saved".localize()
            case .History:                                     return "History".localize()
            case .YouTube:                                     return "YouTube"
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
                    view?.image = UIImage(named: "saved")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
                case "Read":
                    view?.image = UIImage(named: "checkmark")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
                default: break
                }
            case History:
                view?.image = UIImage(named: "history")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
            case Saved:
                view?.image = UIImage(named: "saved")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
            case .YouTube:
                view?.image = UIImage(named: "youtube")
            case .SoundCloud:
                view?.image = UIImage(named: "soundcloud_icon")
            case .Pocket:  break
            case .Twitter: break
            case .FeedlyCategory:
                view?.image = UIImage(named: "folder")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
            case .UncategorizedSubscription(let subscription):
                view?.sd_setImageWithURL(subscription.thumbnailURL, placeholderImage: UIImage(named: "default_thumb"))
            }
        }
        func child(vc: StreamTreeViewController, index: Int) -> AnyObject {
            switch self {
            case .GlobalResource: return []
            case .History:        return []
            case .Saved:          return []
            case .YouTube:
                let i = vc.youtubeActivityLoader.itemsOfPlaylist.startIndex.advancedBy(index)
                return vc.youtubeActivityLoader.itemsOfPlaylist.keys[i]
            case .SoundCloud:     return []
            case .Pocket:         return []
            case .Twitter:        return []
            case .FeedlyCategory(let category):
                if let streams = vc.streamListLoader.streamListOfCategory[category] {
                    return streams[index]
                } else {
                    return []
                }
            case .UncategorizedSubscription: return []
            }
        }
        func numOfChild(vc: StreamTreeViewController) -> Int {
            switch self {
            case .GlobalResource: return 0
            case .History:        return 0
            case .Saved:          return 0
            case .YouTube:
                return vc.youtubeActivityLoader.itemsOfPlaylist.count
            case .SoundCloud:     return 0
            case .Pocket:         return 0
            case .Twitter:        return 0
            case .FeedlyCategory(let category):
                if let streams = vc.streamListLoader.streamListOfCategory[category] {
                    return streams.count
                } else {
                    return 0
                }
            case .UncategorizedSubscription: return 0
            }
        }
    }

    var treeView:              RATreeView?
    var sections:              [Section]
    var streamListLoader:      StreamListLoader
    var observer:              Disposable?
    var refreshDisposable:     Disposable?
    var youtubeActivityLoader: YouTubeActivityLoader
    var youtubeObserver:       Disposable?

    var apiClient:   CloudAPIClient    { return CloudAPIClient.sharedInstance }
    var appDelegate: AppDelegate       { return UIApplication.sharedApplication().delegate as! AppDelegate }
    var root:        UIViewController? { return view.window?.rootViewController }

    var refreshControl: UIRefreshControl?

    func defaultSections() -> [Section] {
        var sections: [Section] = []
        if let userId = FeedlyAPI.profile?.id {
            sections.append(.GlobalResource(FeedlyKit.Category.All(userId)))
            sections.append(.GlobalResource(FeedlyKit.Tag.Saved(userId)))
            sections.append(.GlobalResource(FeedlyKit.Tag.Read(userId)))
        } else {
            sections.append(.Saved)
        }
        sections.append(.History)
        sections.append(.YouTube)
        sections.append(.SoundCloud)
        return sections
    }

    init() {
        sections              = []
        streamListLoader      = StreamListLoader()
        youtubeActivityLoader = YouTubeActivityLoader()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        sections              = []
        streamListLoader      = StreamListLoader()
        youtubeActivityLoader = YouTubeActivityLoader()
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
        youtubeObserver?.dispose()
    }

    func showPreference() {
        let prefvc = PreferenceViewController()
        root?.presentViewController(UINavigationController(rootViewController:prefvc), animated: true, completion: nil)
    }

    func addStream() {
        let admvc = AddStreamMenuViewController(streamListLoader: streamListLoader)
        root?.presentViewController(UINavigationController(rootViewController:admvc), animated: true, completion: nil)
    }

    func showDefaultStream() {
        if let profile = CloudAPIClient.profile {
            showStream(stream: FeedlyKit.Category.All(profile.id))
        } else {
            let streams: [Stream] = streamListLoader.streamListOfCategory.values.flatMap { $0 }
            if streams.count > 0 {
                showStream(stream: streams[Int(arc4random_uniform(UInt32(streams.count)))])
            } else {
                showStream(stream: RecommendFeed.sampleStream())
            }
        }
    }

    func showStream(section section: Section) {
        switch section {
        case .GlobalResource(let stream):
            showStream(stream: stream)
        case .Saved:
            showSavedStream()
        case .History:
            showHistory()
        case .SoundCloud:
            if SoundCloudKit.APIClient.isLoggedIn {
                showSoundCloudActivities()
            } else {
                let vc = UINavigationController(rootViewController: SoundCloudOAuthViewController())
                presentViewController(vc, animated: true, completion: {})
            }
        case .YouTube:
            if YouTubeAPIClient.isLoggedIn {
                return
            } else {
                let vc = UINavigationController(rootViewController: YouTubeOAuthViewController())
                presentViewController(vc, animated: true, completion: {})
            }
        case .Pocket:         return
        case .Twitter:        return
        case .FeedlyCategory: return
        case .UncategorizedSubscription(let subscription):
            showStream(stream: subscription)
        }
    }

    func showStream(stream stream: Stream) {
        let vc = StreamTimelineTableViewController(streamLoader: StreamLoader(stream: stream))
        appDelegate.miniPlayerViewController?.setCenterViewController(vc)
    }

    func showSavedStream() {
        let vc = SavedStreamTimelineTableViewController(streamLoader: SavedStreamLoader())
        appDelegate.miniPlayerViewController?.setCenterViewController(vc)
    }

    func showHistory() {
        let vc = HistoryTableViewController(streamLoader: HistoryLoader())
        appDelegate.miniPlayerViewController?.setCenterViewController(vc)
    }

    func showYouTubeActivities(playlist: YouTubePlaylist) {
        let vc = YouTubeActivityTableViewController(activityLoader: youtubeActivityLoader, playlist: playlist)
        appDelegate.miniPlayerViewController?.setCenterViewController(vc)
    }

    func showSoundCloudActivities() {
        let vc = SoundCloudActivityTableViewController()
        appDelegate.miniPlayerViewController?.setCenterViewController(vc)
    }

    func observeStreamList() {
        observer?.dispose()
        observer = streamListLoader.signal.observeNext({ event in
            switch event {
            case .StartLoading:
                self.refreshControl?.beginRefreshing()
            case .CompleteLoading:
                let categories = self.streamListLoader.categories.filter({
                    $0 != self.streamListLoader.uncategorized
                })
                self.sections  = self.defaultSections()
                self.sections.appendContentsOf(categories.map({ Section.FeedlyCategory($0) }))
                self.sections.appendContentsOf(self.streamListLoader.uncategorizedStreams.map {
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

    func observeYouTubeActivityLoader() {
        youtubeObserver?.dispose()
        youtubeObserver = youtubeActivityLoader.signal.observeNext({ event in
            switch event {
            case .StartLoading:    self.treeView?.reloadData()
            case .CompleteLoading: self.treeView?.reloadData()
            case .FailToLoad:      self.treeView?.reloadData()
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
        youtubeObserver?.dispose()
        observeYouTubeActivityLoader()
        youtubeActivityLoader.clear()
        youtubeActivityLoader.fetchChannels()
        treeView?.reloadData()
        refreshDisposable?.dispose()
        refreshDisposable = streamListLoader.refresh().on(
            next: {
                if let miniPlayerVC = self.appDelegate.miniPlayerViewController {
                    if !miniPlayerVC.hasCenterViewController() {
                        self.showDefaultStream()
                    }
                }
            }
        ).start()
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
            return sections[index].numOfChild(self)
        }
        return 0
    }

    func treeView(treeView: RATreeView!, indentationLevelForRowForItem item: AnyObject!) -> Int {
        if let _ = item as? Stream {
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
            let num = section.numOfChild(self)
            if num > 0 {
                cell.textLabel?.text = "\(section.title) (\(num))"
            } else {
                cell.textLabel?.text = "\(section.title)"
            }
        } else if let stream = item as? Stream {
            cell.textLabel?.text = stream.streamTitle
            if let subscription = stream as? Subscription {
                cell.imageView?.sd_setImageWithURL(subscription.thumbnailURL, placeholderImage: UIImage(named: "default_thumb"))
            }
        } else if let playlist = item as? YouTubePlaylist {
            cell.textLabel?.text = playlist.title.localize()
            cell.imageView?.sd_setImageWithURL(playlist.thumbnailURL, placeholderImage: UIImage(named: "default_thumb"))
        }
        return cell
    }
    
    func treeView(treeView: RATreeView!, child index: Int, ofItem item: AnyObject!) -> AnyObject! {
        if item == nil {
            return index
        }
        if let sectionIndex = item as? Int {
            return sections[sectionIndex].child(self, index: index)
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
        } else if let playlist = item as? YouTubePlaylist {
            showYouTubeActivities(playlist)
        }
    }

    func treeView(treeView: RATreeView!, canEditRowForItem item: AnyObject!) -> Bool {
        if let index = item as? Int {
            switch sections[index] {
            case Section.UncategorizedSubscription: return true
            default:                                return false
            }
        } else if let _ = item as? Stream {
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
                if let i = streamListLoader.uncategorizedStreams.indexOf(subscription) {
                    unsubscribeTo(subscription, index: i, category: uncategorized)
                }
            default: break
            }
        } else if let _ = item as? Stream {
            let sectionIndex = treeView.parentForItem(item) as! Int
            switch sections[sectionIndex] {
            case .FeedlyCategory(let category):
                if let streams = streamListLoader.streamListOfCategory[category] {
                    let stream = item as! Stream
                    if let i = streams.indexOf(stream) {
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
