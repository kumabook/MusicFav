//
//  PreferenceViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 1/10/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

class PreferenceViewController: UITableViewController {
    
    enum Section: Int {
        case Genenral = 0
        static let count = 1
    }
    
    enum GeneralRow: Int {
        case LoginOrLogout  = 0
        static let count = 1
        var title: String {
            switch self {
            case .LoginOrLogout:
                if FeedlyAPIClient.sharedInstance.isLoggedIn {
                    return "Logout".localize()
                } else {
                    return "Login".localize()
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "close".localize(),
                                                                style: UIBarButtonItemStyle.Plain,
                                                               target: self,
                                                               action: "close")
        self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(true)
        self.tableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func close() {
        self.navigationController?.dismissViewControllerAnimated(true, nil)
    }

    func logout() {
        let client = FeedlyAPIClient.sharedInstance
        client.clearAllAccount()
        client.profile = nil
        let notification = NSNotification(name: "loggedOut", object: nil)
        NSNotificationCenter.defaultCenter().postNotification(notification)
    }
    
    func showLoginViewController() {
        self.dismissViewControllerAnimated(false, nil)
        let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        appDelegate.miniPlayerViewController?.showOAuthViewController()
    }
    
    func showLogoutDialog() {
        let ac = UIAlertController(title: "Logout".localize(),
                                 message: "Are you sure you want to logout?".localize(),
                          preferredStyle: UIAlertControllerStyle.Alert)
        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default) { (action) in
            self.logout()
        }
        let cancelAction = UIAlertAction(title: "Canel", style: UIAlertActionStyle.Cancel) { (action) in
        }
        ac.addAction(okAction)
        ac.addAction(cancelAction)
        presentViewController(ac, animated: true, completion: nil)
    }


    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return Section.count
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = Section(rawValue: section)!
        switch section {
        case .Genenral:
            return GeneralRow.count
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath) as UITableViewCell
        let section = Section(rawValue: indexPath.section)!
        switch section {
        case .Genenral:
            let row = GeneralRow(rawValue: indexPath.item)!
            cell.textLabel?.text = row.title
        }

        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let section = Section(rawValue: indexPath.section)!
        switch section {
        case .Genenral:
            let row = GeneralRow(rawValue: indexPath.item)!
            switch row {
            case .LoginOrLogout:
                if FeedlyAPIClient.sharedInstance.isLoggedIn {
                    showLogoutDialog()
                } else {
                    showLoginViewController()
                }
            }
        }
    }
}
