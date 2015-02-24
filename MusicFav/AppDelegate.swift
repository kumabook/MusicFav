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
    var miniPlayerViewController: MiniPlayerViewController?
    var readingPlaylist:          Playlist?
    var playingPlaylist:          Playlist? {
        get {
            return miniPlayerViewController?.currentPlaylist
        }
    }
    let sampleFeeds = [
        "feed/http://spincoaster.com/feed",
        "feed/http://matome.naver.jp/feed/topic/1Hinb"
    ]

    var leftVisibleWidth:  CGFloat? { get { return miniPlayerViewController?.mainViewController.leftVisibleWidth } }
    var rightVisibleWidth: CGFloat? { get { return miniPlayerViewController?.mainViewController.rightVisibleWidth } }

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        self.appearanceManager           = AppearanceManager()
        self.appearanceManager?.apply()
        self.window                      = UIWindow(frame: UIScreen.mainScreen().bounds)
        self.miniPlayerViewController    = MiniPlayerViewController()
        self.window?.rootViewController  = self.miniPlayerViewController
        self.window?.makeKeyAndVisible()
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
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
    }

    override func remoteControlReceivedWithEvent(event: UIEvent) {
        if event.type == UIEventType.RemoteControl {
            
            switch event.subtype {
            case UIEventSubtype.RemoteControlPlay:
                self.miniPlayerViewController?.toggle()
            case UIEventSubtype.RemoteControlPause:
                self.miniPlayerViewController?.toggle()
            case UIEventSubtype.RemoteControlTogglePlayPause:
                self.miniPlayerViewController?.toggle()
            case UIEventSubtype.RemoteControlPreviousTrack:
                self.miniPlayerViewController?.previous()
            case UIEventSubtype.RemoteControlNextTrack:
                self.miniPlayerViewController?.next()
            default:
                break;
            }
        }
    }
}

