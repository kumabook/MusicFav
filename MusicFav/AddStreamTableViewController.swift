//
//  AddStreamTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/15/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveSwift
import FeedlyKit
import MusicFeeder
import MBProgressHUD
import PageMenu

class AddStreamTableViewController: UITableViewController {
    let cellHeight:        CGFloat = 100
    let accessoryWidth:    CGFloat = 30
    var isLoggedIn: Bool { return CloudAPIClient.account != nil }
    let subscriptionRepository: SubscriptionRepository!
    init(subscriptionRepository: SubscriptionRepository) {
        self.subscriptionRepository = subscriptionRepository
        super.init(nibName: nil, bundle: nil)
    }
    required init(coder aDecoder: NSCoder) {
        subscriptionRepository = SubscriptionRepository()
        super.init(nibName: nil, bundle: nil)
    }

    deinit {}

    func getSubscribables() -> [FeedlyKit.Stream] {
        return [] // should be overrided in subclass
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title:"Add".localize(),
                                                            style: UIBarButtonItemStyle.plain,
                                                           target: self,
                                                           action: #selector(AddStreamTableViewController.add))
        navigationItem.rightBarButtonItem?.isEnabled = false
        tableView.allowsMultipleSelection = true
    }

    func reloadData(_ keepSelection: Bool) {
        if keepSelection, let indexes = tableView.indexPathsForSelectedRows {
            tableView.reloadData()
            for index in indexes {
                tableView.selectRow(at: index, animated: false, scrollPosition: UITableViewScrollPosition.none)
            }
        } else {
            tableView.reloadData()
        }
    }

    func isSelected(_ indexPath: IndexPath) -> Bool {
        if let indexPaths = tableView.indexPathsForSelectedRows {
            return indexPaths.contains(where: { $0 == indexPath})
        }
        return false
    }

    func updateAddButton() {
        if let count = tableView.indexPathsForSelectedRows?.count {
            navigationItem.rightBarButtonItem?.isEnabled = count > 0
        } else {
            navigationItem.rightBarButtonItem?.isEnabled = false
        }
        if let p = parent as? CAPSPageMenu, let pp = p.parent as? SearchStreamPageMenuController {
            pp.updateAddButton()
        }
    }

    func setAccessoryView(_ cell: UITableViewCell, indexPath: IndexPath) {
        if isSelected(indexPath) {
            var image             = UIImage(named: "checkmark")
            image                 = image!.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
            let imageView         = UIImageView(image: image)
            imageView.frame       = CGRect(x: 0, y: 0, width: accessoryWidth, height: cellHeight)
            imageView.contentMode = UIViewContentMode.scaleAspectFit
            imageView.tintColor   = UIColor.theme
            cell.accessoryView    = imageView
        } else {
            cell.accessoryView = UIView(frame: CGRect(x: 0, y: 0, width: accessoryWidth, height: cellHeight))
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            setAccessoryView(cell, indexPath: indexPath)
        }
        updateAddButton()
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            setAccessoryView(cell, indexPath: indexPath)
        }
        updateAddButton()
    }

    func close() {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }

    func add() {
        let subscribables: [FeedlyKit.Stream] = getSubscribables()
        Logger.sendUIActionEvent(self, action: "add", label: "")
        let ctc = CategoryTableViewController(subscribables: subscribables, subscriptionRepository: subscriptionRepository)
        navigationController?.pushViewController(ctc, animated: true)
    }
}
