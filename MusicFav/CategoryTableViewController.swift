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
    var feed: Feed?
    var HUD: MBProgressHUD!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
        navigationItem.title = "Select Category"
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
        let ac = UIAlertController(title: "New Category", message: nil, preferredStyle: UIAlertControllerStyle.Alert)
        ac.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: { (action) -> Void in
        }))
        ac.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
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
            if let f = feed { subscribeTo(f, category: category) }
        }
    }

    func subscribeTo(feed: Feed, category: FeedlyKit.Category) {
        MBProgressHUD.showHUDAddedTo(view, animated: true)
        FeedlyAPIClient.sharedInstance.client.subscribeTo(feed, categories: [category]) { (req, res, error) -> Void in
            MBProgressHUD.hideHUDForView(self.view, animated:false)
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
        if let f = feed { subscribeTo(f, category: categories[indexPath.item]) }
    }
}
