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
        setupRealm()
        listenItLater()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func beginRequestWithExtensionContext(context: NSExtensionContext) {
        super.beginRequestWithExtensionContext(context)
    }

    func setupRealm() {
        RealmMigration.groupIdentifier = "group.io.kumabook.MusicFav"
        RealmMigration.migrateListenItLater()
    }

    func listenItLater() {
        let fail = { self.notifyResult(ListenItLaterResult.Error) }
        messageView.hidden = true
        self.extensionContext!.inputItems.forEach { inputItem in
            inputItem.attachments.flatMap({ $0 })?.forEach { _itemProvider in
                guard  let itemProvider = _itemProvider as? NSItemProvider                 else { fail(); return }
                if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                    itemProvider.loadItemForTypeIdentifier(kUTTypeURL as String, options: nil) { (url, error) in
                        if url is NSURL {
                            fail()
                        }
                    }
                } else if itemProvider.hasItemConformingToTypeIdentifier(kUTTypePropertyList as String) {
                    itemProvider.loadItemForTypeIdentifier(kUTTypePropertyList as String, options: nil) { (item, error) in
                        guard let results: NSDictionary = item as? NSDictionary                                else { fail(); return }
                        guard let dic = results[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary else { fail(); return }
                        guard let url = dic["url"] as? String, title = dic["title"] as? String                 else { fail(); return }
                        self.notifyResult(self.saveEntry(url: url, title: title))
                    }
                } else {
                    fail()
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
