//
//  CategoryTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2/18/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import LlamaKit
import FeedlyKit
import MBProgressHUD

class CategoryTableViewController: UITableViewController {
    let client = CloudAPIClient.sharedInstance

    var HUD:              MBProgressHUD!
    let subscribable:     Subscribable!
    let streamListLoader: StreamListLoader!
    var observer:         Disposable?

    var categories: [FeedlyKit.Category] { return streamListLoader.streamListOfCategory.keys.array }

    init(subscribable: Subscribable, streamListLoader: StreamListLoader) {
        self.subscribable     = subscribable
        self.streamListLoader = streamListLoader
        super.init(nibName: nil, bundle: nil)
    }

    required init(coder aDecoder: NSCoder) {
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
        HUD = MBProgressHUD.createCompletedHUD(self.view)
        navigationController?.view.addSubview(HUD)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
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
        observer = streamListLoader.signal.observe({ event in
            switch event {
            case .StartLoading: break
            case .CompleteLoading:
                self.tableView.reloadData()
            case .FailToLoad(let e):
                let ac = CloudAPIClient.alertController(error: e, handler: { (action) in })
            case .StartUpdating:
                MBProgressHUD.showHUDAddedTo(self.navigationController!.view, animated: true)
            case .FailToUpdate(let e):
                let ac = CloudAPIClient.alertController(error: e, handler: { (action) in })
                self.presentViewController(ac, animated: true, completion: nil)
            case .CreateAt(let subscription):
                MBProgressHUD.hideHUDForView(self.navigationController!.view, animated:false)
                self.HUD.show(true , duration: 1.0, after: { () -> Void in
                    self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
                    return
                })
            case .RemoveAt(let index, let subscription, let category): break
            }
        })
    }

    func newCategory() {
        let ac = UIAlertController(title: "New Category".localize(), message: nil, preferredStyle: UIAlertControllerStyle.Alert)
        ac.addAction(UIAlertAction(title: "Cancel".localize(), style: UIAlertActionStyle.Cancel, handler: { (action) -> Void in
        }))
        ac.addAction(UIAlertAction(title: "OK".localize(), style: UIAlertActionStyle.Default, handler: { (action) -> Void in
            if let textField = ac.textFields?.first as? UITextField {
                if let category = self.streamListLoader.createCategory(textField.text) {
                    self.subscribeTo(category)
                }
            }
        }))
        ac.addTextFieldWithConfigurationHandler({(text:UITextField!) -> Void in
        })
        presentViewController(ac, animated: true, completion: nil)
    }

    func subscribeTo(category: FeedlyKit.Category) {
        var subscription: Subscription?
        switch subscribable as Subscribable {
        case Subscribable.ToFeed(let feed):
            subscription = Subscription(feed: feed, categories: [category])
        case .ToBlog(let blog):
            subscription = Subscription(id: blog.feedId,
                                     title: blog.siteName,
                                categories: [category])
        }
        if let s = subscription {
            streamListLoader.subscribeTo(s)
        }
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath) as UITableViewCell
        cell.textLabel?.text = categories[indexPath.item].label
        return cell
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        subscribeTo(categories[indexPath.item])
    }
}
