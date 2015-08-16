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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var appearanceManager:        AppearanceManager?
    var paymentManager:           PaymentManager?
    var window:                   UIWindow?
    var coverViewController:      DraggableCoverViewController?
    var miniPlayerViewController: MiniPlayerViewController?
    var player:                   Player<PlayerObserver>?
    var selectedPlaylist:         MusicFeeder.Playlist?
    var playingPlaylist:          MusicFeeder.Playlist? {
        get {
            return miniPlayerViewController?.currentPlaylist
        }
    }
    var playerViewController:     PlayerViewController? {
        get { return coverViewController?.coverViewController as? PlayerViewController }
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
        player                      = Player()
        appearanceManager           = AppearanceManager()
        appearanceManager?.apply()
        window                      = UIWindow(frame: UIScreen.mainScreen().bounds)
        miniPlayerViewController    = MiniPlayerViewController(player: player!)
        coverViewController         = DraggableCoverViewController(coverViewController: PlayerViewController(player: player!),
            floorViewController: miniPlayerViewController!)
        window?.rootViewController  = self.coverViewController
    }

    func setupAudioSession(application: UIApplication) {
        let audioSession = AVAudioSession()
        audioSession.setCategory(AVAudioSessionCategoryPlayback, error: nil)
        application.beginReceivingRemoteControlEvents()
    }

    func setupAPIClient() {
        FeedlyAPI.setup()
        SoundCloudAPIClient.loadConfig()
    }

    func startTutorial() {
        let vc = TutorialViewController()
        coverViewController?.presentViewController(vc, animated: true, completion: {})
    }

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        let mainBundle = NSBundle.mainBundle()
        let fabricConfig = FabricConfig(filePath: mainBundle.pathForResource("fabric", ofType: "json")!)
        if !fabricConfig.skip {
            var crashlytics = Crashlytics.startWithAPIKey(fabricConfig.apiKey)
        }
        TrackStore.migration()
        if let path = mainBundle.pathForResource("google_analytics", ofType: "json") {
            GAIConfig.setup(path)
        }
        paymentManager = PaymentManager()
        setupAudioSession(application)
        setupAPIClient()
        registerNSUserDefaults()
        if isFirstLaunch {
            Playlist.createDefaultPlaylist()
            Track.youTubeVideoQuality = YouTubeVideoQuality.Medium360
            FeedlyAPI.notificationDateComponents = UILocalNotification.defaultNotificationDateComponents
            markAsLaunched()
        }
        setupMainViewControllers()
        window?.makeKeyAndVisible()
        if !didFinishTutorial { startTutorial() }
        reload()
        UILocalNotification.setup(application)
        Logger.sendStartSession()
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        playerViewController?.disablePlayerView()
        dispatch_async(dispatch_get_main_queue()) { player?.keepPlaying() }
    }

    func applicationDidEnterBackground(application: UIApplication) {
        dispatch_async(dispatch_get_main_queue()) { player?.keepPlaying() }
    }

    func applicationWillEnterForeground(application: UIApplication) {
        playerViewController?.enablePlayerView()
    }

    func applicationDidBecomeActive(application: UIApplication) {
        application.applicationIconBadgeNumber = 0
    }

    func applicationWillTerminate(application: UIApplication) {
        Logger.sendEndSession()
    }

    func application(application: UIApplication, performFetchWithCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        UpdateChecker().check(application, completionHandler: completionHandler)
    }

    func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
    }

    override func remoteControlReceivedWithEvent(event: UIEvent) {
        if event.type == UIEventType.RemoteControl {
            
            switch event.subtype {
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
        let vc               = miniPlayerViewController?.streamTreeViewController
        vc?.streamListLoader = StreamListLoader()
        vc?.showStream(stream: StreamListLoader.defaultStream())
        vc?.refresh()
    }

    func showStreamSelectViewController() {
        if let loader = streamListLoader {
            let stvc = AddStreamMenuViewController(streamListLoader: loader)
            let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.3 * Double(NSEC_PER_SEC)))
            dispatch_after(delayTime, dispatch_get_main_queue()) {
               self.miniPlayerViewController?.presentViewController(UINavigationController(rootViewController:stvc), animated: true, completion: nil)
                return
            }
        }
    }
}

