//
//  ListenItLaterViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/2/15.
//  Copyright © 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import MobileCoreServices
import Realm
import MusicFeeder
import FeedlyKit

enum ListenItLaterResult {
    case Success(Entry)
    case AlreadyExists(Entry)
    case Error
    var message: String {
        switch self {
        case .Success(_):       return "Saved!".localize()
        case .AlreadyExists(_): return "Saved!".localize()
        case .Error(_):         return "Sorry, something wrong".localize()
        }
    }
}

@objc(ListenItLaterViewController)
class ListenItLaterViewController: UIViewController {
    let delaySec: Double = 2

    @IBOutlet weak var messageView: UIView!
    @IBOutlet weak var messabeLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        listenItLater()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func beginRequestWithExtensionContext(context: NSExtensionContext) {
        super.beginRequestWithExtensionContext(context)
    }

    func listenItLater() {
        messageView.hidden = true
        self.extensionContext!.inputItems.forEach { inputItem in
            inputItem.attachments.flatMap({ $0 })?.forEach { _itemProvider in
                if let itemProvider = _itemProvider as? NSItemProvider {
                    if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                        itemProvider.loadItemForTypeIdentifier(kUTTypeURL as String, options: nil) { (url, error) in
                            if let _ = url as? NSURL {
                                self.notifyResult(ListenItLaterResult.Error)
                            }
                        }
                    } else if itemProvider.hasItemConformingToTypeIdentifier(kUTTypePropertyList as String) {
                        itemProvider.loadItemForTypeIdentifier(kUTTypePropertyList as String, options: nil) { (item, error) in
                            if let results: NSDictionary = item as? NSDictionary {
                                if let dic = results[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary {
                                    if let url = dic["url"] as? String, title = dic["title"] as? String {
                                        self.notifyResult(self.saveEntry(url: url, title: title))
                                    } else {
                                        self.notifyResult(ListenItLaterResult.Error)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func saveEntry(url url: String, title: String) -> ListenItLaterResult {
        let entry       = Entry(id: url)
        entry.title     = title
        entry.crawled   = NSDate().timestamp
        entry.recrawled = NSDate().timestamp
        entry.published = NSDate().timestamp
        entry.alternate = [Link(href: url, type: "text/html", length: 0)]
        
        if ListenItLaterEntryStore.create(entry) {
            return ListenItLaterResult.Success(entry)
        } else {
            return ListenItLaterResult.AlreadyExists(entry)
        }
    }

    func notifyResult(result: ListenItLaterResult) {
        let queue = dispatch_get_main_queue()
        dispatch_async(queue) {
            self.messageView.hidden = false
            self.messabeLabel.text  = result.message
        }
        let startTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delaySec * Double(NSEC_PER_SEC)))
        dispatch_after(startTime, queue) {
            switch result {
            case .Success(_):
                self.extensionContext?.completeRequestReturningItems([], completionHandler: nil)
            case .AlreadyExists(_):
                self.extensionContext?.completeRequestReturningItems([], completionHandler: nil)
            case .Error:
                self.extensionContext?.completeRequestReturningItems([], completionHandler: nil)
            }
        }
    }
}
