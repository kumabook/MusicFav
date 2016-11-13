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
import ReactiveSwift
import FeedlyKit
import MusicFeeder
import Fabric
import Crashlytics
import XCDYouTubeKit
import PlayerKit
import SoundCloudKit
import DrawerController

public typealias PlaylistQueue = PlayerKit.PlaylistQueue

class AppPlayerObserver: PlayerObserver {
    var appDelegate: AppDelegate { return UIApplication.shared.delegate as! AppDelegate }
    internal override func listen(_ event: Event) {
        guard let state = appDelegate.player?.currentState else { return }
        switch event {
        case .trackSelected(let track, _, _):
            if state == .play {
                let _ = HistoryStore.add(track as! MusicFeeder.Track)
            }
        case .statusChanged:
            guard let track = appDelegate.player?.currentTrack else { return }
            if state == .play {
                let _ = HistoryStore.add(track as! MusicFeeder.Track)
            }
        default: break
        }
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    enum Event {
        case willResignActive
        case didEnterBackground
        case willEnterForeground
        case didBecomeActive
        case willTerminate
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
    var mainViewController: DrawerController? { return miniPlayerViewController?.drawlerController }
    var leftVisibleWidth:   CGFloat? { return mainViewController?.visibleLeftDrawerWidth}
    var rightVisibleWidth:  CGFloat? { return mainViewController?.visibleRightDrawerWidth }
    var streamRepository: StreamRepository? {
        return miniPlayerViewController?.streamTreeViewController?.streamRepository
    }

    var userDefaults:          UserDefaults { return UserDefaults.standard }
    var isFirstLaunch:         Bool           { return self.userDefaults.bool(forKey: "firstLaunch") }
    var didFinishTutorial:     Bool           { return self.userDefaults.bool(forKey: "finishTutorial") }
    var didFinishSelectStream: Bool           { return self.userDefaults.bool(forKey: "finishSelectStream") }
    func markAsLaunched()     { UserDefaults.standard.set(false, forKey: "firstLaunch") }
    func finishTutorial()     { UserDefaults.standard.set(true,  forKey: "finishTutorial") }
    func finishSelectStream() { UserDefaults.standard.set(true,  forKey: "finishSelectStream") }

    func registerNSUserDefaults() {
        userDefaults.register(defaults: ["firstLaunch":    true])
        userDefaults.register(defaults: ["finishTutorial": false])
        userDefaults.register(defaults: ["finishSelectStream": false])
    }

    func setupMainViewControllers() {
        player                       = Player()
        appearanceManager            = AppearanceManager()
        appearanceManager?.apply()
        player?.addObserver(playerObserver)
        player?.addObserver(NowPlayingInfoCenter(player: player!))
        window                       = UIWindow(frame: UIScreen.main.bounds)
        miniPlayerViewController     = MiniPlayerViewController(player: player!)
        let playerPageViewController = PlayerPageViewController<PlayerViewController, MiniPlayerView>(player: player!)
        coverViewController          = CoverViewController(ceilingViewController: playerPageViewController,
            floorViewController: miniPlayerViewController!)
        miniPlayerViewController?.hideMiniPlayer(false)
        coverViewController?.hideCoverViewController(false)
        window?.rootViewController  = self.coverViewController
    }

    func setupAudioSession(_ application: UIApplication) {
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
        coverViewController?.present(vc, animated: true, completion: {})
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let pipe = Signal<AppDelegate.Event, NSError>.pipe()
        signal   = pipe.0
        observer = pipe.1
        let mainBundle = Bundle.main
        let fabricConfig = FabricConfig(filePath: mainBundle.path(forResource: "fabric", ofType: "json")!)
        if !fabricConfig.skip {
            Crashlytics.start(withAPIKey: fabricConfig.apiKey)
        }
        RealmMigration.groupIdentifier = "group.io.kumabook.MusicFav"
        RealmMigration.migrateAll()
        if let path = mainBundle.path(forResource: "google_analytics", ofType: "json") {
            GAIConfig.setup(path)
        }
        paymentManager = PaymentManager()
        Playlist.sharedOrderBy = OrderBy.number(.asc)
        setupAPIClient()
        registerNSUserDefaults()
        if isFirstLaunch {
            Playlist.createDefaultPlaylist()
            Track.youTubeVideoQuality = YouTubeVideoQuality.medium360
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
        UILocalNotification.setup(application)
        Logger.sendStartSession()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        observer?.send(value: Event.willResignActive)
        playerPageViewController?.disablePlayerView()
        Shortcut.updateShortcutItems(application)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        observer?.send(value: Event.didEnterBackground)
        playerPageViewController?.disablePlayerView()
        Shortcut.updateShortcutItems(application)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        observer?.send(value: Event.willEnterForeground)
        playerPageViewController?.enablePlayerView()
        reloadExpiredTracks()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        observer?.send(value: Event.didBecomeActive)
        application.applicationIconBadgeNumber = 0
        ListenItLaterEntryStore.moveToSaved()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        observer?.send(value: Event.willTerminate)
        Logger.sendEndSession()
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        UpdateChecker().check(application, completionHandler: completionHandler)
    }

    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
    }

    @available(iOS 9.0, *)
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if let shortcut = Shortcut(fullType: shortcutItem.type) {
            if mainViewController?.centerViewController == nil {
                let startTime = DispatchTime.now() + Double(Int64(Shortcut.delaySec * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                DispatchQueue.main.asyncAfter(deadline: startTime) { () -> Void in
                    completionHandler(shortcut.handleShortCutItem())
                }
            } else {
                completionHandler(shortcut.handleShortCutItem())
            }
        }
    }

    override func remoteControlReceived(with event: UIEvent?) {
        if let e = event, e.type == UIEventType.remoteControl {
            switch e.subtype {
            case UIEventSubtype.remoteControlPlay:
                self.miniPlayerViewController?.player?.toggle()
            case UIEventSubtype.remoteControlPause:
                self.miniPlayerViewController?.player?.toggle()
            case UIEventSubtype.remoteControlTogglePlayPause:
                self.miniPlayerViewController?.player?.toggle()
            case UIEventSubtype.remoteControlPreviousTrack:
                self.miniPlayerViewController?.player?.previous()
            case UIEventSubtype.remoteControlNextTrack:
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
        if let repo = streamRepository {
            let _ = repo.subscribeTo(RecommendFeed.sampleStream(), categories: [])
            let stvc = AddStreamMenuViewController(streamRepository: repo)
            let delayTime = DispatchTime.now() + Double(Int64(0.3 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            DispatchQueue.main.asyncAfter(deadline: delayTime) {
               self.miniPlayerViewController?.present(UINavigationController(rootViewController:stvc), animated: true, completion: nil)
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

    func toggle(_ trackIndex: Int, playlist: MusicFeeder.Playlist, playlistQueue: PlaylistQueue) {
        setupAudioSession(UIApplication.shared)
        if player?.toggle(trackIndex, playlist: playlist, playlistQueue: playlistQueue) ?? false {
            showMiniPlayer()
        }
    }

    func toggle() {
        setupAudioSession(UIApplication.shared)
        player?.toggle()
    }
    func play()  {
        setupAudioSession(UIApplication.shared)

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

