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
    let client = FeedlyAPIClient.sharedInstance
    var categories: [FeedlyKit.Category] = []
    var HUD: MBProgressHUD!
    let subscribable: Subscribable!

    init(subscribable: Subscribable) {
        self.subscribable = subscribable
        super.init(nibName: nil, bundle: nil)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

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
        fetch()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func fetch() {
        client.fetchCategories()
            .deliverOn(MainScheduler())
            .start(
                next: {categories in
                    self.categories = categories
                },
                error: {error in
                    let ac = FeedlyAPIClient.alertController(error: error, handler: { (action) in
                    })
                },
                completed: {
                    self.tableView.reloadData()
            })
    }

    func newCategory() {
        let ac = UIAlertController(title: "New Category".localize(), message: nil, preferredStyle: UIAlertControllerStyle.Alert)
        ac.addAction(UIAlertAction(title: "Cancel".localize(), style: UIAlertActionStyle.Cancel, handler: { (action) -> Void in
        }))
        ac.addAction(UIAlertAction(title: "OK".localize(), style: UIAlertActionStyle.Default, handler: { (action) -> Void in
            if let textField = ac.textFields?.first as? UITextField {
                self.createCategory(textField.text)
            }
        }))
        ac.addTextFieldWithConfigurationHandler({(text:UITextField!) -> Void in
        })
        presentViewController(ac, animated: true, completion: nil)
    }

    func createCategory(label: String) {
        if let profile = FeedlyAPIClient.sharedInstance.profile {
            let category = FeedlyKit.Category(label: label, profile: profile)
            subscribeTo(category)
        }
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
        if let s = subscription { subscribeTo(s) }
    }

    func subscribeTo(subscription: Subscription) {
        MBProgressHUD.showHUDAddedTo(navigationController!.view, animated: true)
        FeedlyAPIClient.sharedInstance.client.subscribeTo(subscription) { (req, res, error) -> Void in
            MBProgressHUD.hideHUDForView(self.navigationController!.view, animated:false)
            if let e = error {
                let ac = FeedlyAPIClient.alertController(error: e, handler: { (action) in })
                self.presentViewController(ac, animated: true, completion: nil)
            } else {
                self.HUD.show(true , duration: 1.0, after: { () -> Void in
                    self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
                    return
                })
            }
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
