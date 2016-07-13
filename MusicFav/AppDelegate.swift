//
//  AppDelegate.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/19/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import CoreData
import AVFoundation
import ReactiveCocoa
import FeedlyKit
import MusicFeeder
import Fabric
import Crashlytics
import XCDYouTubeKit
import PlayerKit
import JASidePanels
import SoundCloudKit

public typealias PlaylistQueue = PlayerKit.PlaylistQueue

class AppPlayerObserver: PlayerObserver {
    var appDelegate: AppDelegate { return UIApplication.sharedApplication().delegate as! AppDelegate }
    internal override func listen(event: Event) {
        guard let state = appDelegate.player?.currentState else { return }
        switch event {
        case .TrackSelected(let track, _, _):
            if state == .Play {
                HistoryStore.add(track as! MusicFeeder.Track)
            }
        case .StatusChanged:
            guard let track = appDelegate.player?.currentTrack else { return }
            if state == .Play {
                HistoryStore.add(track as! MusicFeeder.Track)
            }
        default: break
        }
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    enum Event {
        case WillResignActive
        case DidEnterBackground
        case WillEnterForeground
        case DidBecomeActive
        case WillTerminate
    }
    var appearanceManager:        AppearanceManager?
    var paymentManager:           PaymentManager?
    var window:                   UIWindow?
    var coverViewController:      CoverViewController?
    var miniPlayerViewController: MiniPlayerViewController?
    var player:                   Player?
    var signal:                   Signal<AppDelegate.Event, NSError>?
    var observer:                 Signal<AppDelegate.Event, NSError>.Observer?
    var playerObserver:           AppPlayerObserver = AppPlayerObserver()
    var selectedPlaylist:         MusicFeeder.Playlist?
    var playingPlaylist:          MusicFeeder.Playlist? {
        get {
            return miniPlayerViewController?.currentPlaylist
        }
    }
    var playerPageViewController: PlayerPageViewController<PlayerViewController, MiniPlayerView>? {
        get { return coverViewController?.ceilingViewController as? PlayerPageViewController<PlayerViewController, MiniPlayerView> }
    }
    var mainViewController: JASidePanelController? { return miniPlayerViewController?.mainViewController as? JASidePanelController }
    var leftVisibleWidth:   CGFloat? { return mainViewController?.leftVisibleWidth }
    var rightVisibleWidth:  CGFloat? { return mainViewController?.rightVisibleWidth }
    var streamListLoader: StreamListLoader? {
        return miniPlayerViewController?.streamTreeViewController?.streamListLoader
    }

    var userDefaults:          NSUserDefaults { return NSUserDefaults.standardUserDefaults() }
    var isFirstLaunch:         Bool           { return self.userDefaults.boolForKey("firstLaunch") }
    var didFinishTutorial:     Bool           { return self.userDefaults.boolForKey("finishTutorial") }
    var didFinishSelectStream: Bool           { return self.userDefaults.boolForKey("finishSelectStream") }
    func markAsLaunched()     { NSUserDefaults.standardUserDefaults().setBool(false, forKey: "firstLaunch") }
    func finishTutorial()     { NSUserDefaults.standardUserDefaults().setBool(true,  forKey: "finishTutorial") }
    func finishSelectStream() { NSUserDefaults.standardUserDefaults().setBool(true,  forKey: "finishSelectStream") }

    func registerNSUserDefaults() {
        userDefaults.registerDefaults(["firstLaunch":    true])
        userDefaults.registerDefaults(["finishTutorial": false])
        userDefaults.registerDefaults(["finishSelectStream": false])
    }

    func setupMainViewControllers() {
        player                       = Player()
        appearanceManager            = AppearanceManager()
        appearanceManager?.apply()
        player?.addObserver(playerObserver)
        player?.addObserver(NowPlayingInfoCenter(player: player!))
        window                       = UIWindow(frame: UIScreen.mainScreen().bounds)
        miniPlayerViewController     = MiniPlayerViewController(player: player!)
        let playerPageViewController = PlayerPageViewController<PlayerViewController, MiniPlayerView>(player: player!)
        coverViewController          = CoverViewController(ceilingViewController: playerPageViewController,
            floorViewController: miniPlayerViewController!)
        miniPlayerViewController?.hideMiniPlayer(false)
        coverViewController?.hideCoverViewController(false)
        window?.rootViewController  = self.coverViewController
    }

    func setupAudioSession(application: UIApplication) {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayback)
            try audioSession.setActive(true)
        } catch _ {
            Logger.error("failed to set")
        }
        application.beginReceivingRemoteControlEvents()
    }

    func setupAPIClient() {
        CloudAPIClient.setup()
        SoundCloudKit.APIClient.setup()
        YouTubeAPIClient.setup()
    }

    func startTutorial() {
        let vc = TutorialViewController()
        coverViewController?.presentViewController(vc, animated: true, completion: {})
    }

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        let pipe = Signal<AppDelegate.Event, NSError>.pipe()
        signal   = pipe.0
        observer = pipe.1
        let mainBundle = NSBundle.mainBundle()
        let fabricConfig = FabricConfig(filePath: mainBundle.pathForResource("fabric", ofType: "json")!)
        if !fabricConfig.skip {
            Crashlytics.startWithAPIKey(fabricConfig.apiKey)
        }
        RealmMigration.groupIdentifier = "group.io.kumabook.MusicFav"
        RealmMigration.migrateAll()
        if let path = mainBundle.pathForResource("google_analytics", ofType: "json") {
            GAIConfig.setup(path)
        }
        paymentManager = PaymentManager()
        setupAPIClient()
        registerNSUserDefaults()
        if isFirstLaunch {
            Playlist.createDefaultPlaylist()
            Track.youTubeVideoQuality = YouTubeVideoQuality.Medium360
            CloudAPIClient.notificationDateComponents = UILocalNotification.defaultNotificationDateComponents
            markAsLaunched()
        }
        setupMainViewControllers()
        if #available(iOS 9.0, *) {
            if let p = player {
                Shortcut.observePlayer(p)
            }
            Shortcut.updateShortcutItems(application)
        }
        player?.addObserver(HistoryManager())
        window?.makeKeyAndVisible()
        if !didFinishTutorial { startTutorial() }
        reload()
        UILocalNotification.setup(application)
        Logger.sendStartSession()
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        observer?.sendNext(Event.WillResignActive)
        playerPageViewController?.disablePlayerView()
        Shortcut.updateShortcutItems(application)
    }

    func applicationDidEnterBackground(application: UIApplication) {
        observer?.sendNext(Event.DidEnterBackground)
        playerPageViewController?.disablePlayerView()
        Shortcut.updateShortcutItems(application)
    }

    func applicationWillEnterForeground(application: UIApplication) {
        observer?.sendNext(Event.WillEnterForeground)
        mainViewController?.centerPanel
        playerPageViewController?.enablePlayerView()
        reloadExpiredTracks()
    }

    func applicationDidBecomeActive(application: UIApplication) {
        observer?.sendNext(Event.DidBecomeActive)
        application.applicationIconBadgeNumber = 0
        ListenItLaterEntryStore.moveToSaved()
    }

    func applicationWillTerminate(application: UIApplication) {
        observer?.sendNext(Event.WillTerminate)
        Logger.sendEndSession()
    }

    func application(application: UIApplication, performFetchWithCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        UpdateChecker().check(application, completionHandler: completionHandler)
    }

    func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
    }

    @available(iOS 9.0, *)
    func application(application: UIApplication, performActionForShortcutItem shortcutItem: UIApplicationShortcutItem, completionHandler: (Bool) -> Void) {
        if let shortcut = Shortcut(fullType: shortcutItem.type) {
            if mainViewController?.centerPanel == nil {
                let startTime = dispatch_time(DISPATCH_TIME_NOW, Int64(Shortcut.delaySec * Double(NSEC_PER_SEC)))
                dispatch_after(startTime, dispatch_get_main_queue()) { () -> Void in
                    completionHandler(shortcut.handleShortCutItem())
                }
            } else {
                completionHandler(shortcut.handleShortCutItem())
            }
        }
    }

    override func remoteControlReceivedWithEvent(event: UIEvent?) {
        if let e = event where e.type == UIEventType.RemoteControl {
            switch e.subtype {
            case UIEventSubtype.RemoteControlPlay:
                self.miniPlayerViewController?.player?.toggle()
            case UIEventSubtype.RemoteControlPause:
                self.miniPlayerViewController?.player?.toggle()
            case UIEventSubtype.RemoteControlTogglePlayPause:
                self.miniPlayerViewController?.player?.toggle()
            case UIEventSubtype.RemoteControlPreviousTrack:
                self.miniPlayerViewController?.player?.previous()
            case UIEventSubtype.RemoteControlNextTrack:
                self.miniPlayerViewController?.player?.next()
            default:
                break;
            }
        }
    }

    func didLogin()  { reload() }
    func didLogout() { reload() }

    func reload() {
        let vc = miniPlayerViewController?.streamTreeViewController
        vc?.refresh()
    }

    func showAddStreamMenuViewController() {
        if let loader = streamListLoader {
            loader.subscribeTo(RecommendFeed.sampleStream(), categories: [])
            let stvc = AddStreamMenuViewController(streamListLoader: loader)
            let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.3 * Double(NSEC_PER_SEC)))
            dispatch_after(delayTime, dispatch_get_main_queue()) {
               self.miniPlayerViewController?.presentViewController(UINavigationController(rootViewController:stvc), animated: true, completion: nil)
                return
            }
        }
    }

    func showMiniPlayer() {
        coverViewController?.showCoverViewController(true) {
            self.miniPlayerViewController?.showMiniPlayer(false)
        }
    }

    // Player control functions

    func toggle(trackIndex: Int, playlist: MusicFeeder.Playlist, playlistQueue: PlaylistQueue) {
        setupAudioSession(UIApplication.sharedApplication())
        if player?.toggle(trackIndex, playlist: playlist, playlistQueue: playlistQueue) ?? false {
            showMiniPlayer()
        }
    }

    func toggle() {
        setupAudioSession(UIApplication.sharedApplication())
        player?.toggle()
    }
    func play()  {
        setupAudioSession(UIApplication.sharedApplication())

        if player?.play() ?? false {
            showMiniPlayer()
        }
    }
    func pause() { player?.pause() }

    func reloadExpiredTracks() {
        guard let playlists = player?.playlistQueue.playlists else { return }
        playlists.forEach {
            guard let p = $0 as? MusicFeeder.Playlist else { return }
            p.reloadExpiredTracks().start()
        }
    }
}

