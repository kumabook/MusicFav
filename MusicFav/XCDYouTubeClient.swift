//
//  XCDYouTubeClient.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/7/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import XCDYouTubeKit
import ReactiveCocoa
import LlamaKit

extension XCDYouTubeClient {
    func fetchVideo(identifier: String) -> SignalProducer<XCDYouTubeVideo, NSError> {
        return SignalProducer { (sink, disposable) in
            let operation = self.getVideoWithIdentifier(identifier, completionHandler: { (video, error) -> Void in
                if let e = error {
                    sink.put(.Error(Box(error)))
                    return
                }
                sink.put(.Next(Box(video)))
                sink.put(.Completed)
            })
            disposable.addDisposable {
                operation.cancel()
            }
            return
        }
    }
}

extension XCDYouTubeVideoQuality {
    var label: String {
        switch self {
        case .Small240:  return  "Small 240".localize()
        case .Medium360: return  "Medium 360".localize()
        case .HD720:     return  "HD 720".localize()
        default:         return  "Unknown".localize()
        }
    }
    static func buildAlertActions(handler: () -> ()) -> [UIAlertAction] {
        var actions: [UIAlertAction] = []
        actions.append(UIAlertAction(title: XCDYouTubeVideoQuality.Small240.label,
                                     style: .Default,
                                   handler: { action in Track.youTubeVideoQuality = .Small240; handler() }))
        actions.append(UIAlertAction(title: XCDYouTubeVideoQuality.Medium360.label,
                                     style: .Default,
                                   handler: { action in Track.youTubeVideoQuality = .Medium360; handler() }))
        actions.append(UIAlertAction(title: XCDYouTubeVideoQuality.HD720.label,
                                     style: .Default,
                                   handler: { action in  Track.youTubeVideoQuality = .HD720; handler() }))
        return actions
    }
}
