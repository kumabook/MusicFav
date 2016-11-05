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
    case success(Entry)
    case alreadyExists(Entry)
    case error
    var message: String {
        switch self {
        case .success(_):       return "Saved!".localize()
        case .alreadyExists(_): return "Saved!".localize()
        case .error(_):         return "Sorry, something wrong".localize()
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

    override func beginRequest(with context: NSExtensionContext) {
        super.beginRequest(with: context)
    }

    func setupRealm() {
        RealmMigration.groupIdentifier = "group.io.kumabook.MusicFav"
        RealmMigration.migrateListenItLater()
    }

    func listenItLater() {
        let fail = { self.notifyResult(ListenItLaterResult.error) }
        messageView.isHidden = true
        self.extensionContext!.inputItems.forEach { inputItem in
            (inputItem as AnyObject).attachments.flatMap({ $0 })?.forEach { _itemProvider in
                guard  let itemProvider = _itemProvider as? NSItemProvider                 else { fail(); return }
                if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                    itemProvider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { (value, error) in
                        guard let url = value as? URL else { fail(); return }
                        self.notifyResult(self.saveEntry(url: url.absoluteString, title: url.absoluteString))
                    }
                } else if itemProvider.hasItemConformingToTypeIdentifier(kUTTypePropertyList as String) {
                    itemProvider.loadItem(forTypeIdentifier: kUTTypePropertyList as String, options: nil) { (item, error) in
                        guard let results: NSDictionary = item as? NSDictionary                                else { fail(); return }
                        guard let dic = results[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary else { fail(); return }
                        guard let url = dic["url"] as? String, let title = dic["title"] as? String                 else { fail(); return }
                        self.notifyResult(self.saveEntry(url: url, title: title))
                    }
                } else {
                    fail()
                }
            }
        }
    }
    
    func saveEntry(url: String, title: String) -> ListenItLaterResult {
        let entry       = Entry(id: url)
        entry.title     = title
        entry.crawled   = Date().timestamp
        entry.recrawled = Date().timestamp
        entry.published = Date().timestamp
        entry.alternate = [Link(href: url, type: "text/html", length: 0)]
        
        if ListenItLaterEntryStore.create(entry) {
            return ListenItLaterResult.success(entry)
        } else {
            return ListenItLaterResult.alreadyExists(entry)
        }
    }

    func notifyResult(_ result: ListenItLaterResult) {
        let queue = DispatchQueue.main
        queue.async {
            self.messageView.isHidden = false
            self.messabeLabel.text  = result.message
        }
        let startTime = DispatchTime.now() + Double(Int64(delaySec * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        queue.asyncAfter(deadline: startTime) {
            switch result {
            case .success(_):
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            case .alreadyExists(_):
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            case .error:
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }
}
