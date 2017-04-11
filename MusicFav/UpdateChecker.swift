//
//  UpdateChecker.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 5/11/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import ReactiveSwift
import FeedlyKit
import MusicFeeder

class UpdateChecker {
    let apiClient = CloudAPIClient.sharedInstance
    let perPage   = 3
    let newerThan: Date
    init() {
        if let fromDate = CloudAPIClient.lastChecked {
            newerThan = fromDate
        } else {
            newerThan = Date().yesterDay
        }
    }
    var nextNotificationDate: Date? {
        if let components = CloudAPIClient.notificationDateComponents {
            return Date.nextDateFromComponents(components as DateComponents)
        }
        return nil
    }
    func check(_ application: UIApplication, completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
        if let fireDate = nextNotificationDate {
            fetchNewTracks().on(
                failed: { error in
                    UIScheduler().schedule { completionHandler?(UIBackgroundFetchResult.failed) }
            }, completed: {
            }, interrupted: {
                UIScheduler().schedule { completionHandler?(UIBackgroundFetchResult.failed) }
            }, value: { tracks in
                UIScheduler().schedule {
                    let tracksInfo = UILocalNotification.buildNewTracksInfo(application, tracks: tracks)
                    application.cancelAllLocalNotifications()
                    if tracksInfo.count > 0 {
                        let notification = UILocalNotification.newTracksNotification(tracksInfo, fireDate: fireDate)
                        application.scheduleLocalNotification(notification)
                        completionHandler?(UIBackgroundFetchResult.newData)
                    } else {
                        completionHandler?(UIBackgroundFetchResult.noData)
                    }
                }
                CloudAPIClient.lastChecked = Date()
            }).start()
        } else {
            application.cancelAllLocalNotifications()
            completionHandler?(UIBackgroundFetchResult.noData)
        }
    }
    func fetchNewTracks() -> SignalProducer<[Track], NSError> {
        var entriesSignal: SignalProducer<[Entry], NSError>!
        if let profile = CloudAPIClient.profile {
            entriesSignal = apiClient.fetchEntries(streamId: FeedlyKit.Category.All(profile.id).streamId,
                                                  newerThan: newerThan.timestamp,
                                                 unreadOnly: true,
                                                    perPage: perPage)
                .map { $0.items }
        } else {
            entriesSignal = SubscriptionRepository().loadLocalSubscriptions()
                .map { (table: [FeedlyKit.Category: [FeedlyKit.Stream]]) -> [FeedlyKit.Stream] in
                    return table.values.flatMap { $0 }
                }.map { streams in
                    return streams.map { stream in
                        return self.apiClient.fetchEntries(streamId: stream.streamId,
                                                          newerThan: self.newerThan.timestamp,
                                                         unreadOnly: true,
                                                            perPage: self.perPage).map { $0.items }
                        }.reduce(SignalProducer<[Entry], NSError>(value: [])) {
                            SignalProducer.combineLatest($0, $1).map {
                                var list = $0.0; list.append(contentsOf: $0.1); return list
                            }
                    }
            }.flatten(FlattenStrategy.concat)
        }
        return entriesSignal.map { entries in
            entries.reduce(SignalProducer<[Track], NSError>(value: [])) {
                SignalProducer.combineLatest($0, self.fetchPlaylistOfEntry($1)).map {
                    var list = $0.0; list.append(contentsOf: $0.1.getTracks()); return list
                }
            }
        }.flatten(.concat)
    }

    func fetchPlaylistOfEntry(_ entry: Entry) -> SignalProducer<Playlist, NSError> {
        if let url = entry.url {
            return PinkSpiderAPIClient.sharedInstance.playlistify(url, errorOnFailure: false)
        } else {
            return SignalProducer<Playlist, NSError>.empty
        }
    }
}
