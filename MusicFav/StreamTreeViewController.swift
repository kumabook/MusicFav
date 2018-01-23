//
//  StreamTreeViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/21/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveSwift
import FeedlyKit
import MusicFeeder
import RATreeView
import MBProgressHUD
import SoundCloudKit
import YouTubeKit

class StreamTreeViewController: UIViewController, RATreeViewDelegate, RATreeViewDataSource {
    enum Section {
        case globalResource(FeedlyKit.Stream)
        case feedlyCategory(FeedlyKit.Category)
        case uncategorizedSubscription(FeedlyKit.Subscription)
        case favorite
        case history
        case youTube
        case soundCloud
        case spotify
        case pocket
        case twitter

        var title: String {
            switch self {
            case .globalResource(let stream):                  return stream.streamTitle.localize()
            case .favorite:                                    return "Favorite".localize()
            case .history:                                     return "History".localize()
            case .youTube:                                     return "YouTube"
            case .soundCloud:                                  return "SoundCloud"
            case .spotify:                                     return "Spotify Top Tracks"
            case .pocket:                                      return "Pocket"
            case .twitter:                                     return "Twitter"
            case .feedlyCategory(let category):                return category.label
            case .uncategorizedSubscription(let subscription): return subscription.streamTitle
            }
        }
        func setThumbImage(_ view: UIImageView?) {
            switch self {
            case .globalResource(let stream):
                switch stream.streamTitle {
                case "All":
                    view?.image = UIImage(named: "home")?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
                case "Saved":
                    view?.image = UIImage(named: "saved")?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
                case "Read":
                    view?.image = UIImage(named: "checkmark")?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
                default: break
                }
            case .history:
                view?.image = UIImage(named: "history")?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
            case .favorite:
                view?.image = UIImage(named: "fav_entry")?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
            case .youTube:
                view?.image = UIImage(named: "youtube")
            case .soundCloud:
                view?.image = UIImage(named: "soundcloud_icon")
            case .spotify:
                view?.image = UIImage(named: "spotify")
            case .pocket:  break
            case .twitter: break
            case .feedlyCategory:
                view?.image = UIImage(named: "folder")?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
            case .uncategorizedSubscription(let subscription):
                view?.sd_setImage(with: subscription.thumbnailURL, placeholderImage: UIImage(named: "default_thumb"))
            }
        }
        func child(_ vc: StreamTreeViewController, index: Int) -> Any {
            switch self {
            case .globalResource: return []
            case .history:        return []
            case .favorite:       return []
            case .youTube:
                let i = vc.youtubeActivityLoader.itemsOfPlaylist.index(vc.youtubeActivityLoader.itemsOfPlaylist.startIndex, offsetBy: index)
                return vc.youtubeActivityLoader.itemsOfPlaylist.keys[i]
            case .soundCloud:     return []
            case .spotify:        return []
            case .pocket:         return []
            case .twitter:        return []
            case .feedlyCategory(let category):
                if let streams = vc.subscriptionRepository.streamListOfCategory[category] {
                    return streams[index]
                } else {
                    return []
                }
            case .uncategorizedSubscription: return []
            }
        }
        func numOfChild(_ vc: StreamTreeViewController) -> Int {
            switch self {
            case .globalResource: return 0
            case .history:        return 0
            case .favorite:       return 0
            case .youTube:
                return vc.youtubeActivityLoader.itemsOfPlaylist.count
            case .soundCloud:     return 0
            case .spotify:        return 0
            case .pocket:         return 0
            case .twitter:        return 0
            case .feedlyCategory(let category):
                if let streams = vc.subscriptionRepository.streamListOfCategory[category] {
                    return streams.count
                } else {
                    return 0
                }
            case .uncategorizedSubscription: return 0
            }
        }
    }

    var treeView:               RATreeView?
    var sections:               [Section]
    var subscriptionRepository: SubscriptionRepository
    var observer:               Disposable?
    var refreshDisposable:      Disposable?
    var youtubeActivityLoader:  YouTubeActivityLoader
    var youtubeObserver:        Disposable?

    var apiClient:   CloudAPIClient    { return CloudAPIClient.shared }
    var appDelegate: AppDelegate       { return UIApplication.shared.delegate as! AppDelegate }
    var root:        UIViewController? { return view.window?.rootViewController }

    var refreshControl: UIRefreshControl?

    func defaultSections() -> [Section] {
        var sections: [Section] = []
        if let userId = CloudAPIClient.profile?.id {
            sections.append(.globalResource(FeedlyKit.Category.all(userId)))
            sections.append(.globalResource(FeedlyKit.Tag.saved(userId)))
            sections.append(.globalResource(FeedlyKit.Tag.read(userId)))
        }
        sections.append(.favorite)
        sections.append(.history)
        sections.append(.youTube)
        sections.append(.soundCloud)
        sections.append(.spotify)
        return sections
    }

    init() {
        sections               = []
        subscriptionRepository = SubscriptionRepository()
        youtubeActivityLoader  = YouTubeActivityLoader()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        sections               = []
        subscriptionRepository = SubscriptionRepository()
        youtubeActivityLoader  = YouTubeActivityLoader()
        super.init(coder: aDecoder)
    }

    deinit {}

    override func viewDidLoad() {
        super.viewDidLoad()
        let settingsButton  = UIBarButtonItem(image: UIImage(named: "settings"),
                                              style: UIBarButtonItemStyle.plain,
                                             target: self,
                                             action: #selector(StreamTreeViewController.showPreference))
        let addStreamButton = UIBarButtonItem(image: UIImage(named: "add_stream"),
                                              style: UIBarButtonItemStyle.plain,
                                             target: self,
                                             action: #selector(StreamTreeViewController.addStream))
        navigationItem.leftBarButtonItems  = [settingsButton, addStreamButton]
        view.backgroundColor = UIColor.white
        treeView = RATreeView(frame: CGRect(x: 0, y: 0, width: appDelegate.leftVisibleWidth!, height: view.frame.height))
        treeView?.backgroundColor = UIColor.white
        treeView?.delegate = self
        treeView?.dataSource = self
        treeView?.register(StreamTreeViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
        view.addSubview(treeView!)

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action:#selector(StreamTreeViewController.refresh), for:UIControlEvents.valueChanged)
        treeView?.addResreshControl(refreshControl!)
        refresh()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        treeView!.frame = CGRect(x: 0, y: 0, width: appDelegate.leftVisibleWidth!, height: view.frame.height)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        observer?.dispose()
        youtubeObserver?.dispose()
    }

    @objc func showPreference() {
        let prefvc = PreferenceViewController()
        root?.present(UINavigationController(rootViewController:prefvc), animated: true, completion: nil)
    }

    @objc func addStream() {
        let admvc = AddStreamMenuViewController(subscriptionRepository: subscriptionRepository)
        root?.present(UINavigationController(rootViewController:admvc), animated: true, completion: nil)
    }

    func showDefaultStream() {
        if let profile = CloudAPIClient.profile {
            showStream(stream: FeedlyKit.Category.all(profile.id))
        } else {
            let streams: [FeedlyKit.Stream] = subscriptionRepository.streamListOfCategory.values.flatMap { $0 }
            if streams.count > 0 {
                showStream(stream: streams[Int(arc4random_uniform(UInt32(streams.count)))])
            } else {
                showStream(stream: RecommendFeed.sampleStream())
            }
        }
    }

    func showStream(section: Section) {
        switch section {
        case .globalResource(let stream):
            showStream(stream: stream)
        case .favorite:
            showSavedStream()
        case .history:
            showHistory()
        case .soundCloud:
            if SoundCloudKit.APIClient.shared.isLoggedIn {
                showSoundCloudActivities()
            } else {
                SoundCloudKit.APIClient.authorize()
            }
        case .youTube:
            if YouTubeKit.APIClient.isLoggedIn {
                return
            } else {
                YouTubeKit.APIClient.authorize()
            }
        case .spotify:
            if SpotifyAPIClient.shared.isLoggedIn {
                showSpotifyTopTracks()
            } else if let vc = appDelegate.coverViewController {
                SpotifyAPIClient.shared.startAuthenticationFlow(viewController: vc)
            }
        case .pocket:         return
        case .twitter:        return
        case .feedlyCategory: return
        case .uncategorizedSubscription(let subscription):
            showStream(stream: subscription)
        }
    }

    func showStream(stream: FeedlyKit.Stream) {
        let vc = StreamTimelineTableViewController(entryRepository: EntryRepository(stream: stream))
        appDelegate.miniPlayerViewController?.setCenterViewController(vc)
    }

    func showSavedStream() {
        let vc = SavedStreamTimelineTableViewController(entryRepository: SavedEntryRepository())
        appDelegate.miniPlayerViewController?.setCenterViewController(vc)
    }

    func showHistory() {
        let vc = HistoryTableViewController(entryRepository: HistoryRepository())
        appDelegate.miniPlayerViewController?.setCenterViewController(vc)
    }

    func showYouTubeActivities(_ playlist: YouTubeKit.Playlist) {
        let vc = YouTubeActivityTableViewController(activityLoader: youtubeActivityLoader, playlist: playlist)
        appDelegate.miniPlayerViewController?.setCenterViewController(vc)
    }

    func showSoundCloudActivities() {
        let vc = SoundCloudActivityTableViewController()
        appDelegate.miniPlayerViewController?.setCenterViewController(vc)
    }

    func showSpotifyTopTracks() {
        let vc = SpotifyTopTracksTableViewController()
        appDelegate.miniPlayerViewController?.setCenterViewController(vc)
    }

    func observeStreamList() {
        observer?.dispose()
        observer = subscriptionRepository.signal.observeResult({ result in
            guard let event = result.value else { return }
            switch event {
            case .create(_):
                self.treeView?.reloadData()
                MBProgressHUD.hide(for: self.view, animated: true)
            case .startLoading:
                self.refreshControl?.beginRefreshing()
            case .completeLoading:
                let categories = self.subscriptionRepository.categories.filter({
                    $0 != self.subscriptionRepository.uncategorized
                })
                self.sections  = self.defaultSections()
                self.sections.append(contentsOf: categories.map({ Section.feedlyCategory($0) }))
                self.sections.append(contentsOf: self.subscriptionRepository.uncategorizedStreams.map {
                    if let subscription = $0 as? FeedlyKit.Subscription {
                        return Section.uncategorizedSubscription(subscription)
                    } else if let feed = $0 as? Feed {
                        return Section.uncategorizedSubscription(Subscription(feed: feed, categories: []))
                    } else {
                        return Section.uncategorizedSubscription(Subscription(id: "Unknown", title: "Unknown", categories: []) )
                    }
                })
                self.refreshControl?.endRefreshing()
                self.treeView?.reloadData()
                if let miniPlayerVC = self.appDelegate.miniPlayerViewController {
                    if !miniPlayerVC.hasCenterViewController() {
                        self.showDefaultStream()
                    }
                }
            case .failToLoad(let e):
                let _ = CloudAPIClient.alertController(error: e, handler: { (action) -> Void in })
                self.refreshControl?.endRefreshing()
            case .startUpdating:
                MBProgressHUD.showAdded(to: self.view, animated: true)
            case .failToUpdate(let e):
                let _ = MBProgressHUD.hide(for: self.view, animated: true)
                let _ = CloudAPIClient.alertController(error: e, handler: { (action) -> Void in })
            case .remove(let subscription):
                MBProgressHUD.hide(for: self.view, animated: true)
                let _ = MBProgressHUD.showCompletedHUDForView(self.navigationController!.view, animated: true, duration: 1.0, after: {
                    let l = self.subscriptionRepository
                    subscription.categories.forEach { category in
                        if category == l.uncategorized {
                            let i = self.indexOfUncategorizedSubscription(subscription)
                            self.treeView!.deleteItems(at: IndexSet([i]),
                                                       inParent: nil,
                                                       with: RATreeViewRowAnimationRight)
                            self.sections.remove(at: i)
                            self.treeView!.reloadData()
                        } else {
                            if let i = self.subscriptionRepository.uncategorizedStreams.index(of: subscription) {
                                self.treeView!.deleteItems(at: IndexSet([i]),
                                                           inParent: self.treeView!.parent(forItem: subscription),
                                                           with: RATreeViewRowAnimationRight)
                                self.treeView!.reloadRows(forItems: [self.indexOfCategory(category)],
                                                          with: RATreeViewRowAnimationRight)
                            }
                        }
                    }
                })
            }
        })
    }

    func observeYouTubeActivityLoader() {
        youtubeObserver?.dispose()
        youtubeObserver = youtubeActivityLoader.signal.observeResult({ result in
            guard let event = result.value else { return }
            switch event {
            case .startLoading:    self.treeView?.reloadData()
            case .completeLoading: self.treeView?.reloadData()
            case .failToLoad:      self.treeView?.reloadData()
            }
        })
    }

    func indexOfCategory(_ category: FeedlyKit.Category) -> Int {
        var i = 0
        for section in sections {
            switch section {
            case .feedlyCategory(let c): if c == category { return i }
            default:                     break
            }
            i += 1
        }
        return i
    }

    func indexOfUncategorizedSubscription(_ subscription: FeedlyKit.Subscription) -> Int {
        var i = 0
        for section in sections {
            switch section {
            case .uncategorizedSubscription(let sub): if sub == subscription { return i }
            default:                                  break
            }
            i += 1
        }
        return i
    }

    @objc func refresh() {
        observer?.dispose()
        observeStreamList()
        youtubeObserver?.dispose()
        observeYouTubeActivityLoader()
        youtubeActivityLoader.clear()
        youtubeActivityLoader.fetchChannels()
        treeView?.reloadData()
        subscriptionRepository.refresh()
    }

    func unsubscribeTo(_ subscription: FeedlyKit.Subscription, index: Int, category: FeedlyKit.Category) {
        let _ = subscriptionRepository.unsubscribeTo(subscription)
    }

    // MARK: - RATreeView data source
    
    func treeView(_ treeView: RATreeView!, numberOfChildrenOfItem item: Any!) -> Int {
        if item == nil {
            return sections.count
        }
        if let index = item as? Int {
            return sections[index].numOfChild(self)
        }
        return 0
    }

    func treeView(_ treeView: RATreeView!, indentationLevelForRowForItem item: Any!) -> Int {
        if let _ = item as? FeedlyKit.Stream {
            return 1
        } else {
            return 0
        }
    }

    func treeView(_ treeView: RATreeView!, shouldIndentWhileEditingRowForItem item: Any!) -> Bool {
        return true
    }

    func treeView(_ treeView: RATreeView!, cellForItem item: Any!) -> UITableViewCell! {
        let cell = treeView.dequeueReusableCell(withIdentifier: "reuseIdentifier") as! StreamTreeViewCell
        if let i = self.treeView?.levelForCell(forItem: item) { cell.indent = i }
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
        } else if let stream = item as? FeedlyKit.Stream {
            cell.textLabel?.text = stream.streamTitle
            if let subscription = stream as? FeedlyKit.Subscription {
                cell.imageView?.sd_setImage(with: subscription.thumbnailURL, placeholderImage: UIImage(named: "default_thumb"))
            }
        } else if let playlist = item as? YouTubeKit.Playlist {
            cell.textLabel?.text = playlist.title.localize()
            cell.imageView?.sd_setImage(with: playlist.thumbnailURL, placeholderImage: UIImage(named: "default_thumb"))
        }
        return cell
    }
    
    func treeView(_ treeView: RATreeView!, child index: Int, ofItem item: Any!) -> Any! {
        if item == nil {
            return index as AnyObject!
        }
        if let sectionIndex = item as? Int {
            return sections[sectionIndex].child(self, index: index)
        }
        return "Nothing" as AnyObject!
    }

    func treeView(_ treeView: RATreeView!, didSelectRowForItem item: Any!) {
        Logger.sendUIActionEvent(self, action: "didSelectRowForItem", label: "")
        if item == nil {
        } else if let index = item as? Int {
            showStream(section: sections[index])
        } else if let stream = item as? FeedlyKit.Stream {
            showStream(stream:stream)
        } else if let playlist = item as? YouTubeKit.Playlist {
            showYouTubeActivities(playlist)
        }
    }

    func treeView(_ treeView: RATreeView!, canEditRowForItem item: Any!) -> Bool {
        if let index = item as? Int {
            switch sections[index] {
            case Section.uncategorizedSubscription: return true
            default:                                return false
            }
        } else if let _ = item as? FeedlyKit.Stream {
            return true
        }
        return false
    }

    func treeView(_ treeView: RATreeView!, commit editingStyle: UITableViewCellEditingStyle, forRowForItem item: Any!) {
        Logger.sendUIActionEvent(self, action: "commitEditingStyle", label: "")
        if let index = item as? Int {
            switch sections[index] {
            case Section.uncategorizedSubscription(let subscription):
                let uncategorized = subscriptionRepository.uncategorized
                if let i = subscriptionRepository.uncategorizedStreams.index(of: subscription) {
                    unsubscribeTo(subscription, index: i, category: uncategorized)
                }
            default: break
            }
        } else if let _ = item as? FeedlyKit.Stream {
            let sectionIndex = treeView.parent(forItem: item) as! Int
            switch sections[sectionIndex] {
            case .feedlyCategory(let category):
                if let streams = subscriptionRepository.streamListOfCategory[category] {
                    let stream = item as! FeedlyKit.Stream
                    if let i = streams.index(of: stream) {
                        if let subscription = item as? FeedlyKit.Subscription {
                            unsubscribeTo(subscription, index: i, category: category)
                        }
                    }
                }
            default: break
            }
        }
    }
}
