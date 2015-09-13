//
//  CategoryTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2/18/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import FeedlyKit
import MusicFeeder
import MBProgressHUD

class CategoryTableViewController: UITableViewController {
    let client = CloudAPIClient.sharedInstance

    var subscribables:    [Stream]
    var streamListLoader: StreamListLoader!
    var observer:         Disposable?

    var categories: [FeedlyKit.Category] {
        var _categories   = streamListLoader.streamListOfCategory.keys.array
        var list          = [streamListLoader.uncategorized]
        list.extend(_categories.filter({$0 != self.streamListLoader.uncategorized }))
        return list
    }

    init(subscribables: [Stream], streamListLoader: StreamListLoader) {
        self.subscribables    = subscribables
        self.streamListLoader = streamListLoader
        super.init(nibName: nil, bundle: nil)
    }

    required init(coder aDecoder: NSCoder) {
        self.subscribables = []
        super.init(coder: aDecoder)
    }

    deinit {}

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
        navigationItem.title = "Select Category".localize()
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "add_stream"),
                                                            style: UIBarButtonItemStyle.Plain,
                                                           target: self,
                                                           action: "newCategory")
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
        observeStreamList()
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        observer?.dispose()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func observeStreamList() {
        observer?.dispose()
        observer = streamListLoader.signal.observe(next: { event in
            switch event {
            case .StartLoading: break
            case .CompleteLoading:
                self.tableView.reloadData()
            case .FailToLoad(let e):             break
            case .StartUpdating:                 break
            case .FailToUpdate(let e):           break
            case .StartUpdating:                 break
            case .FailToUpdate(let e):           break
            case .RemoveAt(let i, let s, let c): break
            }
        })
    }

    func newCategory() {
        Logger.sendUIActionEvent(self, action: "newCategory", label: "")
        let ac = UIAlertController(title: "New Category".localize(), message: nil, preferredStyle: UIAlertControllerStyle.Alert)
        ac.addAction(UIAlertAction(title: "Cancel".localize(), style: UIAlertActionStyle.Cancel, handler: { (action) -> Void in
            Logger.sendUIActionEvent(self, action: "Cancel", label: "")
        }))
        ac.addAction(UIAlertAction(title: "OK".localize(), style: UIAlertActionStyle.Default, handler: { (action) -> Void in
            if let textField = ac.textFields?.first as? UITextField {
                Logger.sendUIActionEvent(self, action: "OK", label: "")
                if let category = self.streamListLoader.createCategory(textField.text) {
                    self.subscribeTo(category)
                }
            }
        }))
        ac.addTextFieldWithConfigurationHandler({(text:UITextField!) -> Void in
        })
        presentViewController(ac, animated: true, completion: nil)
    }

    func _subscribeTo(category: FeedlyKit.Category) -> SignalProducer<[Subscription], NSError> {
        return subscribables.reduce(SignalProducer(value: [])) {
            combineLatest($0, streamListLoader.subscribeTo($1, categories: [category])) |> map {
                var list = $0.0; list.append($0.1); return list
            }
        }
    }

    func subscribeTo(category: FeedlyKit.Category) {
        MBProgressHUD.showHUDAddedTo(self.navigationController!.view, animated: true)
        _subscribeTo(category) |> start(
            next: {subscriptions in
                MBProgressHUD.hideHUDForView(self.navigationController!.view, animated:false)
            },
            error: {e in
                MBProgressHUD.hideHUDForView(self.navigationController!.view, animated:false)
                let ac = CloudAPIClient.alertController(error: e, handler: { (action) in })
                self.presentViewController(ac, animated: true, completion: nil)
            },
            completed: {
                MBProgressHUD.showCompletedHUDForView(self.navigationController!.view, animated: true, duration: 1.0, after: {
                    self.streamListLoader.refresh().start()
                    self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
                })
            },
            interrupted: {}
        )
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath) as! UITableViewCell
        if categories[indexPath.item] == streamListLoader.uncategorized {
            cell.textLabel?.text = categories[indexPath.item].label.localize()
        } else {
            cell.textLabel?.text = categories[indexPath.item].label
        }
        return cell
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        Logger.sendUIActionEvent(self, action: "didSelectRowAtIndexPath", label: String(indexPath.row))
        subscribeTo(categories[indexPath.item])
    }
}
