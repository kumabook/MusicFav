//
//  PreferenceViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 1/10/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import InAppSettingsKit
import FeedlyKit
import RMDateSelectionViewController

class PreferenceViewController: UITableViewController {
    var appDelegate: AppDelegate { get { return UIApplication.sharedApplication().delegate as! AppDelegate } }
    enum Section: Int {
        case Account     = 0
        case Behavior    = 1
        case Feedback    = 2
        case Other       = 3
        static let count = 4
        var rowCount: Int {
            switch self {
            case .Account:  return AccountRow.count
            case .Behavior: return BehaviorRow.count
            case .Feedback: return FeedbackRow.count
            case .Other:    return OtherRow.count
            }
        }
        func rowTitle(rowIndex: Int) -> String? {
            switch self {
            case .Account:  return AccountRow(rawValue: rowIndex)?.title
            case .Behavior: return BehaviorRow(rawValue: rowIndex)?.title
            case .Feedback: return FeedbackRow(rawValue: rowIndex)?.title
            case .Other:    return OtherRow(rawValue: rowIndex)?.title
            }
        }
        func rowDetail(rowIndex: Int) -> String? {
            switch self {
            case .Account:  return nil
            case .Behavior: return BehaviorRow(rawValue: rowIndex)?.detail
            case .Feedback: return nil
            case .Other:    return nil
            }
        }
        var title: String {
            switch self {
            case .Account:  return "ACCOUNT"
            case .Behavior: return "BEHAVIOR"
            case .Feedback: return "FEEDBACK"
            case .Other:    return ""
            }
        }
    }

    enum AccountRow: Int {
        case LoginOrLogout = 0
        static let count   = 1
        var title: String {
            if CloudAPIClient.sharedInstance.isLoggedIn {
                return "Logout".localize()
            } else {
                return "Login".localize()
            }
        }
    }

    enum BehaviorRow: Int {
        case NotificationTime = 0
        static let count      = 1
        var title: String {
            return "Notification of new arrivals".localize()
        }
        var detail: String {
            if let time = FeedlyAPI.notificationTime {
                return String(format: "%02d:%02d", time.hour, time.minute)
            }
            return "No notification".localize()
        }
    }

    enum FeedbackRow: Int {
        case Feedback    = 0
        case Rate        = 1
        static let count = 2
        var title: String {
            switch self {
            case .Feedback: return "Send Feedback".localize()
            case .Rate:     return "Please Rate MusicFav".localize()
            }
        }
    }
    enum OtherRow: Int {
        case Tutorial    = 0
        case About       = 1
        static let count = 2
        var title: String {
            switch self {
            case .About:    return "About".localize()
            case .Tutorial: return "Tutorial".localize()
            }
        }
    }

    init() {
        super.init(style: UITableViewStyle.Grouped)
    }

    override init!(nibName nibNameOrNil: String!, bundle nibBundleOrNil: NSBundle!) {
        super.init(nibName: nil, bundle:nil)
    }

    required init(coder aDecoder: NSCoder!) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        RMDateSelectionViewController.setLocalizedTitleForSelectButton("Select".localize())
        RMDateSelectionViewController.setLocalizedTitleForCancelButton("Cancel".localize())
        RMDateSelectionViewController.setLocalizedTitleForNowButton("No notification".localize())
        navigationItem.title             = "Preferences".localize()
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Close".localize(),
                                                           style: UIBarButtonItemStyle.Plain,
                                                          target: self,
                                                          action: "close")
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
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
        self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }

    func logout() {
        FeedlyAPI.clearAllAccount()
        FeedlyAPI.profile = nil
        self.dismissViewControllerAnimated(true) {
            self.appDelegate.didLogout()
        }
    }
    
    func showLoginViewController() {
        let oauthvc = FeedlyOAuthViewController()
        navigationController?.pushViewController(oauthvc, animated: true)
    }
    
    func showLogoutDialog() {
        let ac = UIAlertController(title: "Logout".localize(),
                                 message: "Are you sure you want to logout?".localize(),
                          preferredStyle: UIAlertControllerStyle.Alert)
        let okAction = UIAlertAction(title: "OK".localize(), style: UIAlertActionStyle.Default) { (action) in
            self.logout()
        }
        let cancelAction = UIAlertAction(title: "Cancel".localize(), style: UIAlertActionStyle.Cancel) { (action) in
        }
        ac.addAction(okAction)
        ac.addAction(cancelAction)
        presentViewController(ac, animated: true, completion: nil)
    }


    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return Section.count
    }

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let section = Section(rawValue: section) {
            return section.title
        }
        return ""
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let section = Section(rawValue: section) {
            return section.rowCount
        }
        return 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCellStyle.Value1, reuseIdentifier: "reuseIdentifier")
        if let section = Section(rawValue: indexPath.section) {
            if let rowTitle = section.rowTitle(indexPath.row) {
                cell.textLabel?.text = rowTitle
            }
            if let rowDetail = section.rowDetail(indexPath.row) {
                cell.detailTextLabel?.text = rowDetail
            }
        }
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let section = Section(rawValue: indexPath.section)!
        switch section {
        case .Account:
            switch AccountRow(rawValue: indexPath.row)! {
            case .LoginOrLogout:
                if CloudAPIClient.sharedInstance.isLoggedIn {
                    showLogoutDialog()
                } else {
                    showLoginViewController()
                }
            }
        case .Behavior:
            var dateSelectionVC = RMDateSelectionViewController.dateSelectionController()
            dateSelectionVC.selectButtonAction = { (controller, date) in
                let calendar = NSCalendar.currentCalendar()
                FeedlyAPI.notificationTime = calendar.components(NSCalendarUnit.CalendarUnitHour|NSCalendarUnit.CalendarUnitMinute, fromDate: date)
                tableView.reloadData()
            }
            dateSelectionVC.cancelButtonAction = { controller in }
            dateSelectionVC.nowButtonAction = { controller in
                FeedlyAPI.notificationTime = nil
                self.tableView.reloadData()
                dateSelectionVC.dismissViewControllerAnimated(true, completion: {})
            }
            if let time = FeedlyAPI.notificationTime {
                let calendar = NSCalendar.currentCalendar()
                let date = calendar.dateWithEra(1, year: 2015, month: 5, day: 11,
                                                   hour: time.hour, minute: time.minute,
                                                 second: 0, nanosecond: 0)!
                dateSelectionVC.datePicker.date = date
            }
            dateSelectionVC.datePicker.datePickerMode = UIDatePickerMode.Time
            dateSelectionVC.datePicker.minuteInterval = UILocalNotification.notificationTimeMinutesInterval
            presentViewController(dateSelectionVC, animated:true, completion:{})
        case .Feedback:
            switch FeedbackRow(rawValue: indexPath.row)! {
            case .Feedback:
                let vc = FeedbackWebViewController()
                navigationController?.pushViewController(vc, animated: true)
            case .Rate:
                let appleId = "957250852";
                let url = NSURL(string: "itms-apps://itunes.apple.com/app/id\(appleId)")!
                UIApplication.sharedApplication().openURL(url)
            }
        case .Other:
            switch OtherRow(rawValue: indexPath.row)! {
            case .About:
                let vc = IASKAppSettingsViewController()
                vc.showCreditsFooter = false
                navigationController?.pushViewController(vc, animated: true)
                vc.navigationItem.rightBarButtonItems = []
            case .Tutorial:
                let vc = TutorialViewController()
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
}
