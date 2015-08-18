//
//  AddStreamTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/15/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import FeedlyKit
import MusicFeeder
import MBProgressHUD
import PageMenu

class AddStreamTableViewController: UITableViewController {
    let cellHeight:        CGFloat = 100
    let accessoryWidth:    CGFloat = 30
    var isLoggedIn: Bool { return FeedlyAPI.account != nil }
    let streamListLoader: StreamListLoader!
    init(streamListLoader: StreamListLoader) {
        self.streamListLoader = streamListLoader
        super.init(nibName: nil, bundle: nil)
    }
    required init(coder aDecoder: NSCoder) {
        streamListLoader = StreamListLoader()
        super.init(nibName: nil, bundle: nil)
    }

    deinit {}

    func getSubscribables() -> [Stream] {
        return [] // should be overrided in subclass
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title:"Add".localize(),
                                                            style: UIBarButtonItemStyle.Plain,
                                                           target: self,
                                                           action: "add")
        navigationItem.rightBarButtonItem?.enabled = false
        tableView.allowsMultipleSelection = true
    }

    func reloadData(#keepSelection: Bool) {
        let indexPaths = tableView.indexPathsForSelectedRows()
        tableView.reloadData()
        if keepSelection, let indexes = indexPaths as? [NSIndexPath] {
            for index in indexes {
                tableView.selectRowAtIndexPath(index, animated: false, scrollPosition: UITableViewScrollPosition.None)
            }
        }
    }

    func isSelected(#indexPath: NSIndexPath) -> Bool {
        if let indexPaths = tableView.indexPathsForSelectedRows() as? [NSIndexPath] {
            return contains(indexPaths, { $0 == indexPath})
        }
        return false
    }

    func updateAddButton() {
        if let count = tableView.indexPathsForSelectedRows()?.count {
            navigationItem.rightBarButtonItem?.enabled = count > 0
        } else {
            navigationItem.rightBarButtonItem?.enabled = false
        }
        if let p = parentViewController as? CAPSPageMenu, pp = p.parentViewController as? SearchStreamPageMenuController {
            pp.updateAddButton()
        }
    }

    func setAccessoryView(cell: UITableViewCell, indexPath: NSIndexPath) {
        if isSelected(indexPath: indexPath) {
            var image             = UIImage(named: "checkmark")
            image                 = image!.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
            let imageView         = UIImageView(image: image)
            imageView.frame       = CGRect(x: 0, y: 0, width: accessoryWidth, height: cellHeight)
            imageView.contentMode = UIViewContentMode.ScaleAspectFit
            imageView.tintColor   = UIColor.theme
            cell.accessoryView    = imageView
        } else {
            cell.accessoryView = UIView(frame: CGRect(x: 0, y: 0, width: accessoryWidth, height: cellHeight))
        }
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let cell = tableView.cellForRowAtIndexPath(indexPath) {
            setAccessoryView(cell, indexPath: indexPath)
        }
        updateAddButton()
    }

    override func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        if let cell = tableView.cellForRowAtIndexPath(indexPath) {
            setAccessoryView(cell, indexPath: indexPath)
        }
        updateAddButton()
    }

    func close() {
        self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }

    func add() {
        if let indexPaths = tableView.indexPathsForSelectedRows() {
            let subscribables: [Stream] = getSubscribables()
            Logger.sendUIActionEvent(self, action: "add", label: "")
            if isLoggedIn {
                let ctc = CategoryTableViewController(subscribables: subscribables, streamListLoader: streamListLoader)
                navigationController?.pushViewController(ctc, animated: true)
            } else {
                MBProgressHUD.showHUDAddedTo(self.navigationController!.view, animated: true)
                subscribables.reduce(SignalProducer<[Subscription], NSError>(value: [])) {
                    combineLatest($0, self.streamListLoader.subscribeTo($1, categories: [])) |> map {
                        var list = $0.0; list.append($0.1); return list
                    }
                    } |> start(
                        next: { subscriptions in
                            MBProgressHUD.hideHUDForView(self.navigationController!.view, animated:false)
                        }, error: { e in
                            MBProgressHUD.hideHUDForView(self.navigationController!.view, animated:false)
                            let ac = CloudAPIClient.alertController(error: e, handler: { (action) in })
                        }, completed: {
                            MBProgressHUD.showCompletedHUDForView(self.navigationController!.view, animated: true, duration: 1.0, after: {
                                self.streamListLoader.refresh()
                                self.navigationController?.dismissViewControllerAnimated(true, completion: {})
                            })
                    })
            }
        }
    }
}
