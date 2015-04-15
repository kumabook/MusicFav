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
import LlamaKit


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var appearanceManager:        AppearanceManager?
    var window:                   UIWindow?
    var coverViewController:      DraggableCoverViewController?
    var miniPlayerViewController: MiniPlayerViewController?
    var player:                   Player<PlayerObserver>?
    var selectedPlaylist:         Playlist?
    var playingPlaylist:          Playlist? {
        get {
            return miniPlayerViewController?.currentPlaylist
        }
    }
    var playerViewController:     PlayerViewController? {
        get { return coverViewController?.coverViewController as? PlayerViewController }
    }
    var leftVisibleWidth:  CGFloat? { get { return miniPlayerViewController?.mainViewController.leftVisibleWidth } }
    var rightVisibleWidth: CGFloat? { get { return miniPlayerViewController?.mainViewController.rightVisibleWidth } }

    var isFirstLaunch: Bool { return NSUserDefaults.standardUserDefaults().boolForKey("firstLaunch") }
    func markAsLaunched()   { NSUserDefaults.standardUserDefaults().setBool(false, forKey: "firstLaunch") }

    func registerNSUserDefaults() {
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.registerDefaults(["firstLaunch": true])
    }


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        TrackStore.migration()
        registerNSUserDefaults()
        if isFirstLaunch {
            Playlist.createDefaultPlaylist()
            markAsLaunched()
        }
        player                      = Player()
        appearanceManager           = AppearanceManager()
        appearanceManager?.apply()
        window                      = UIWindow(frame: UIScreen.mainScreen().bounds)
        miniPlayerViewController    = MiniPlayerViewController()
        coverViewController         = DraggableCoverViewController(coverViewController: PlayerViewController(),
                                                                   floorViewController: miniPlayerViewController!)
        window?.rootViewController  = self.coverViewController
        window?.makeKeyAndVisible()
        let audioSession = AVAudioSession()
        audioSession.setCategory(AVAudioSessionCategoryPlayback, error: nil)
        application.beginReceivingRemoteControlEvents()
        let feedlyAPIClient = FeedlyAPIClient.sharedInstance
        if feedlyAPIClient.profile == nil {
            feedlyAPIClient.clearAllAccount()
        }
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        playerViewController?.disablePlayerView()
    }

    func applicationDidEnterBackground(application: UIApplication) {
    }

    func applicationWillEnterForeground(application: UIApplication) {
        playerViewController?.enablePlayerView()
    }

    func applicationDidBecomeActive(application: UIApplication) {}

    func applicationWillTerminate(application: UIApplication) {}

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
        let vc               = miniPlayerViewController?.menuViewController
        vc?.streamListLoader = StreamListLoader()
        vc?.showStream(stream: StreamListLoader.defaultStream())
        vc?.refresh()
    }
}

