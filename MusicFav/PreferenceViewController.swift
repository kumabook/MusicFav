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
import MusicFeeder
import RMDateSelectionViewController
import XCDYouTubeKit
import StoreKit
import MBProgressHUD

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
        case Feedly      = 0
        case YouTube     = 1
        static let count = 2
        var title: String {
            switch self {
            case Feedly:
                if CloudAPIClient.isLoggedIn {
                    return "Logout".localize()
                } else {
                    return "Login".localize()
                }
            case YouTube:
                if YouTubeAPIClient.isLoggedIn {
                    return "Disconnect with YouTube"
                } else {
                    return "Connect with YouTube"
                }
            }
        }
    }

    enum BehaviorRow: Int {
        case YouTubeVideoQuality = 0
        case NotificationTime    = 1
        case UnlockEverything    = 2
        case RestorePurchase     = 3
        static var count: Int {
            if PaymentManager.isUnlockedEverything { return 2 }
            else                                   { return 4 }
        }
        var title: String {
            switch self {
            case .YouTubeVideoQuality: return "Video Quality".localize()
            case .NotificationTime:    return "Notification of new arrivals".localize()
            case .UnlockEverything:    return "Unlock Everything".localize()
            case .RestorePurchase:     return "Restore Purchase".localize()
            }
        }
        var detail: String {
            switch self {
            case .YouTubeVideoQuality:
                return Track.youTubeVideoQuality.label
            case .NotificationTime:
                if let components = FeedlyAPI.notificationDateComponents {
                    if components.hour <= 11 {
                        return String(format: "%02d:%02d AM", components.hour, components.minute)
                    } else {
                        return String(format: "%02d:%02d PM", components.hour - 12, components.minute)
                    }
                }
                return "No notification".localize()
            case .UnlockEverything: return ""
            case .RestorePurchase:  return ""
            }
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

    deinit {}

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
        appDelegate.paymentManager?.viewController = self
        Logger.sendScreenView(self)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(true)
        self.tableView.reloadData()
    }

    override func viewWillDisappear(animated: Bool) {
        appDelegate.paymentManager?.viewController = nil
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func close() {
        self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }

    func logout() {
        CloudAPIClient.logout()
        self.dismissViewControllerAnimated(true) {
            self.appDelegate.didLogout()
        }
    }
    
    func showLoginViewController() {
        let oauthvc = FeedlyOAuthViewController()
        navigationController?.pushViewController(oauthvc, animated: true)
    }

    func showYouTubeLoginController() {
        let vc = OAuthViewController(clientId: YouTubeAPIClient.clientId,
                                 clientSecret: YouTubeAPIClient.clientSecret,
                                        scope: YouTubeAPIClient.scope,
                                      authUrl: YouTubeAPIClient.authUrl,
                                     tokenUrl: YouTubeAPIClient.tokenUrl,
                                  redirectUrl: YouTubeAPIClient.redirectUrl,
                                  accountType: YouTubeAPIClient.accountType,
                                keyChainGroup: YouTubeAPIClient.keyChainGroup)
        navigationController?.pushViewController(vc, animated: true)
    }

    func showConfirmDialog(title: String, message: String, action: ((UIAlertAction!) -> Void)) {
        let ac = UIAlertController(title: title.localize(),
            message: message.localize(),
            preferredStyle: UIAlertControllerStyle.Alert)
        let okAction = UIAlertAction(title: "OK".localize(), style: UIAlertActionStyle.Default, handler: action)
        let cancelAction = UIAlertAction(title: "Cancel".localize(), style: UIAlertActionStyle.Cancel) { (action) in
        }
        ac.addAction(okAction)
        ac.addAction(cancelAction)
        presentViewController(ac, animated: true, completion: nil)
    }

    func showLogoutDialog() {
        showConfirmDialog("Logout", message: "Are you sure you want to logout?") { (action) in
            self.logout()
        }
    }

    func showDisonnectYouTubeDialog() {
        showConfirmDialog("Disconnect with YouTube", message: "Are you sure you want to disconnect with YouTube?") { (action) in
            YouTubeAPIClient.clearAllAccount()
            self.tableView?.reloadData()
        }
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
            case .Feedly:
                if CloudAPIClient.isLoggedIn {
                    showLogoutDialog()
                } else {
                    showLoginViewController()
                }
            case .YouTube:
                if YouTubeAPIClient.isLoggedIn {
                    showDisonnectYouTubeDialog()
                } else {
                    showYouTubeLoginController()
                }
            }
        case .Behavior:
            switch BehaviorRow(rawValue: indexPath.row)! {
            case .YouTubeVideoQuality:
                var actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
                for action in YouTubeVideoQuality.buildAlertActions({ self.tableView.reloadData() }) {
                    actionSheet.addAction(action)
                }
                actionSheet.addAction(UIAlertAction(title: "Cancel".localize(), style: .Cancel, handler: { action in }))
                presentViewController(actionSheet, animated: true, completion: {})
            case .NotificationTime:
                var dateSelectionVC = RMDateSelectionViewController.dateSelectionController()
                dateSelectionVC.selectButtonAction = { (controller, date) in
                    let calendar = NSCalendar.currentCalendar()
                    FeedlyAPI.notificationDateComponents = calendar.components(NSCalendarUnit.CalendarUnitHour|NSCalendarUnit.CalendarUnitMinute, fromDate: date)
                    tableView.reloadData()
                    UpdateChecker().check(UIApplication.sharedApplication(), completionHandler: nil)
                }
                dateSelectionVC.cancelButtonAction = { controller in }
                dateSelectionVC.nowButtonAction = { controller in
                    FeedlyAPI.notificationDateComponents = nil
                    self.tableView.reloadData()
                    dateSelectionVC.dismissViewControllerAnimated(true, completion: {})
                    UpdateChecker().check(UIApplication.sharedApplication(), completionHandler: nil)
                }
                if let time = FeedlyAPI.notificationDateComponents {
                    let calendar = NSCalendar.currentCalendar()
                    let date = calendar.dateWithEra(1, year: 2015, month: 5, day: 11,
                                                       hour: time.hour, minute: time.minute,
                                                     second: 0, nanosecond: 0)!
                    dateSelectionVC.datePicker.date = date
                }
                dateSelectionVC.datePicker.datePickerMode = UIDatePickerMode.Time
                dateSelectionVC.datePicker.minuteInterval = UILocalNotification.notificationTimeMinutesInterval
                presentViewController(dateSelectionVC, animated:true, completion:{})
            case .UnlockEverything:
                appDelegate.paymentManager?.purchaseUnlockEverything()
            case .RestorePurchase:
                appDelegate.paymentManager?.restorePurchase()
            }
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
