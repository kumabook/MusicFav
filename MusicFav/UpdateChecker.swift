//
//  UpdateChecker.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 5/11/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import ReactiveCocoa
import FeedlyKit
import MusicFeeder

class UpdateChecker {
    let apiClient = CloudAPIClient.sharedInstance
    let newerThan: NSDate
    init() {
        if let fromDate = FeedlyAPI.lastChecked {
            newerThan = fromDate
        } else {
            newerThan = NSDate().yesterDay
        }
    }
    var nextNotificationDate: NSDate? {
        if let components = FeedlyAPI.notificationDateComponents {
            return NSDate.nextDateFromComponents(components)
        }
        return nil
    }
    func check(application: UIApplication, completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
        let apiClient = CloudAPIClient.sharedInstance
        if let fireDate = nextNotificationDate {
            fetchNewTracks().start(
                next: { tracks in
                    UIScheduler().schedule {
                        var tracksInfo = UILocalNotification.buildNewTracksInfo(application, tracks: tracks)
                        application.cancelAllLocalNotifications()
                        if tracksInfo.count > 0 {
                            let notification = UILocalNotification.newTracksNotification(tracksInfo, fireDate: fireDate)
                            application.scheduleLocalNotification(notification)
                            completionHandler?(UIBackgroundFetchResult.NewData)
                        } else {
                            completionHandler?(UIBackgroundFetchResult.NoData)
                        }
                    }
                    FeedlyAPI.lastChecked = NSDate()
                }, error: { error in
                    UIScheduler().schedule { completionHandler?(UIBackgroundFetchResult.Failed) }
                }, completed: {
                }, interrupted: {
                    UIScheduler().schedule { completionHandler?(UIBackgroundFetchResult.Failed) }
            })
        } else {
            application.cancelAllLocalNotifications()
            completionHandler?(UIBackgroundFetchResult.NoData)
        }
    }
    func fetchNewTracks() -> SignalProducer<[Track], NSError> {
        var entriesSignal: SignalProducer<[Entry], NSError>!
        if let profile = FeedlyAPI.profile {
            entriesSignal = apiClient.fetchEntries(streamId: FeedlyKit.Category.All(profile.id).streamId,
                                                  newerThan: newerThan.timestamp,
                                                 unreadOnly: true)
                |> map { $0.items }
        } else {
            entriesSignal = [StreamListLoader.defaultStream()].map({ subscription in
                return self.apiClient.fetchEntries(streamId: subscription.streamId, newerThan: self.newerThan.timestamp, unreadOnly: true) |> map { $0.items }
            }).reduce(SignalProducer<[Entry], NSError>(value: [])) {
                combineLatest($0, $1) |> map {
                    var list = $0.0; list.extend($0.1); return list
                }
            }
        }
        return entriesSignal |> map { entries in
            entries.reduce(SignalProducer<[Track], NSError>(value: [])) {
                combineLatest($0, self.fetchPlaylistOfEntry($1)) |> map {
                    var list = $0.0; list.extend($0.1.getTracks()); return list
                }
            }
        } |> flatten(.Concat)
    }

    func fetchPlaylistOfEntry(entry: Entry) -> SignalProducer<Playlist, NSError> {
        if let url = entry.url {
            return MusicFavAPIClient.sharedInstance.playlistify(url, errorOnFailure: false)
        } else {
            return SignalProducer<Playlist, NSError>.empty
        }
    }
}