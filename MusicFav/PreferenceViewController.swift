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
import SoundCloudKit
import YouTubeKit
import StoreKit
import MBProgressHUD
import OAuthSwift

class PreferenceViewController: UITableViewController {
    var appDelegate: AppDelegate { get { return UIApplication.shared.delegate as! AppDelegate } }
    enum Section: Int {
        case account     = 0
        case behavior    = 1
        case feedback    = 2
        case other       = 3
        static let count = 4
        var rowCount: Int {
            switch self {
            case .account:  return AccountRow.count
            case .behavior: return BehaviorRow.count
            case .feedback: return FeedbackRow.count
            case .other:    return OtherRow.count
            }
        }
        func rowTitle(_ rowIndex: Int) -> String? {
            switch self {
            case .account:  return AccountRow(rawValue: rowIndex)?.title
            case .behavior: return BehaviorRow(rawValue: rowIndex)?.title
            case .feedback: return FeedbackRow(rawValue: rowIndex)?.title
            case .other:    return OtherRow(rawValue: rowIndex)?.title
            }
        }
        func rowDetail(_ rowIndex: Int) -> String? {
            switch self {
            case .account:  return nil
            case .behavior: return BehaviorRow(rawValue: rowIndex)?.detail
            case .feedback: return nil
            case .other:    return nil
            }
        }
        var title: String {
            switch self {
            case .account:  return "ACCOUNT"
            case .behavior: return "BEHAVIOR"
            case .feedback: return "FEEDBACK"
            case .other:    return ""
            }
        }
    }

    enum AccountRow: Int {
        case feedly      = 0
        case youTube     = 1
        case soundCloud  = 2
        case spotify     = 3
        case appleMusic  = 4
        static let count = 5
        var title: String {
            switch self {
            case .feedly:
                if CloudAPIClient.isLoggedIn {
                    return "Disconnect with Feedly".localize()
                } else {
                    return "Manage feeds with Feedly".localize()
                }
            case .youTube:
                if YouTubeKit.APIClient.isLoggedIn {
                    return "Disconnect with YouTube".localize()
                } else {
                    return "Connect with YouTube".localize()
                }
            case .soundCloud:
                if SoundCloudKit.APIClient.shared.isLoggedIn {
                    return "Disconnect with SoundCloud".localize()
                } else {
                    return "Connect with SoundCloud".localize()
                }
            case .spotify:
                if SpotifyAPIClient.shared.isLoggedIn {
                    return "Disconnect with Spotify".localize()
                } else {
                    return "Connect with Spotify".localize()
                }
            case .appleMusic:
                if #available(iOS 9.3, *) {
                    switch AppleMusicClient.shared.authroizationStatus {
                    case .notDetermined:
                        return "Connect Apple Music".localize()
                    case .denied:
                        return "Connect Apple Music".localize()
                    case .restricted:
                        return "Can not connect Apple Music".localize()
                    case .authorized:
                        return "Connected Apple Music".localize()
                    }
                } else {
                    return "Can not connect Apple Music".localize()
                }
            }
        }
    }

    enum BehaviorRow: Int {
        case youTubeVideoQuality = 0
        case notificationTime    = 1
        case unlockEverything    = 2
        case restorePurchase     = 3
        static var count: Int {
            if PaymentManager.isUnlockedEverything { return 2 }
            else                                   { return 4 }
        }
        var title: String {
            switch self {
            case .youTubeVideoQuality: return "Video Quality".localize()
            case .notificationTime:    return "Notification of new arrivals".localize()
            case .unlockEverything:    return "Unlock Everything".localize()
            case .restorePurchase:     return "Restore Purchase".localize()
            }
        }
        var detail: String {
            switch self {
            case .youTubeVideoQuality:
                return Track.youTubeVideoQuality.label
            case .notificationTime:
                if let c = CloudAPIClient.notificationDateComponents, let h = c.hour, let m = c.minute {
                    if h <= 11 {
                        return String(format: "%02d:%02d AM", h, m)
                    } else {
                        return String(format: "%02d:%02d PM", h - 12, m)
                    }
                }
                return "No notification".localize()
            case .unlockEverything: return ""
            case .restorePurchase:  return ""
            }
        }
    }

    enum FeedbackRow: Int {
        case feedback    = 0
        case rate        = 1
        static let count = 2
        var title: String {
            switch self {
            case .feedback: return "Send Feedback".localize()
            case .rate:     return "Please Rate MusicFav".localize()
            }
        }
    }
    enum OtherRow: Int {
        case tutorial    = 0
        case about       = 1
        static let count = 2
        var title: String {
            switch self {
            case .about:    return "About".localize()
            case .tutorial: return "Tutorial".localize()
            }
        }
    }

    init() {
        super.init(style: UITableViewStyle.grouped)
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle:nil)
    }

    required init?(coder aDecoder: NSCoder) {
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
                                                           style: UIBarButtonItemStyle.plain,
                                                          target: self,
                                                          action: #selector(PreferenceViewController.close))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appDelegate.paymentManager?.viewController = self
        Logger.sendScreenView(self)
        SpotifyAPIClient.shared.pipe.output.observeValues { [weak self] in
            self?.tableView.reloadData()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        self.tableView.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        appDelegate.paymentManager?.viewController = nil
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func close() {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }

    func logout() {
        CloudAPIClient.logout()
        self.dismiss(animated: true) {
            self.appDelegate.didLogout()
        }
    }
    
    func showLoginViewController() {
        CloudAPIClient.authorize() {
            self.tableView?.reloadData()
        }
    }

    func showYouTubeLoginController() {
        YouTubeKit.APIClient.authorize(self) {
            self.tableView?.reloadData()
        }
    }

    func showSoundCloudLoginController() {
        SoundCloudKit.APIClient.authorize(self.navigationController) {
            self.tableView?.reloadData()
        }
    }

    func showSpotifyLoginController() {
        SpotifyAPIClient.shared.startAuthenticationFlow(viewController: self)
    }

    func showConfirmDialog(_ title: String, message: String, action: @escaping ((UIAlertAction!) -> Void)) {
        let ac = UIAlertController(title: title.localize(),
            message: message.localize(),
            preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "OK".localize(), style: UIAlertActionStyle.default, handler: action)
        let cancelAction = UIAlertAction(title: "Cancel".localize(), style: UIAlertActionStyle.cancel) { (action) in
        }
        ac.addAction(okAction)
        ac.addAction(cancelAction)
        present(ac, animated: true, completion: nil)
    }

    func showLogoutDialog() {
        showConfirmDialog("Logout", message: "Are you sure you want to disconnect with Feedly?") { (action) in
            self.logout()
        }
    }

    func showDisonnectYouTubeDialog() {
        showConfirmDialog("Disconnect with YouTube", message: "Are you sure you want to disconnect with YouTube?") { (action) in
            YouTubeKit.APIClient.clearAllAccount()
            self.tableView?.reloadData()
            self.appDelegate.reload()
        }
    }

    func showDisonnectSoundCloudDialog() {
        showConfirmDialog("Disconnect with SoundCloud", message: "Are you sure you want to disconnect with SoundCloud?") { (action) in
            SoundCloudKit.APIClient.clearAllAccount()
            self.tableView?.reloadData()
            self.appDelegate.reload()
        }
    }

    func showDisonnectSpotifyDialog() {
        showConfirmDialog("Disconnect with Spotify", message: "Are you sure you want to disconnect with Spotify?") { (action) in
            SpotifyAPIClient.shared.logout()
            self.tableView?.reloadData()
            self.appDelegate.reload()
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let section = Section(rawValue: section) {
            return section.title
        }
        return ""
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let section = Section(rawValue: section) {
            return section.rowCount
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCellStyle.value1, reuseIdentifier: "reuseIdentifier")
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
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = Section(rawValue: indexPath.section)!
        switch section {
        case .account:
            switch AccountRow(rawValue: indexPath.row)! {
            case .feedly:
                if CloudAPIClient.isLoggedIn {
                    showLogoutDialog()
                } else {
                    showLoginViewController()
                }
            case .youTube:
                if YouTubeKit.APIClient.isLoggedIn {
                    showDisonnectYouTubeDialog()
                } else {
                    showYouTubeLoginController()
                }
            case .soundCloud:
                if SoundCloudKit.APIClient.shared.isLoggedIn {
                    showDisonnectSoundCloudDialog()
                } else {
                    showSoundCloudLoginController()
                }
            case .spotify:
                if SpotifyAPIClient.shared.isLoggedIn {
                    showDisonnectSpotifyDialog()
                } else {
                    showSpotifyLoginController()
                }
            case .appleMusic:
                if #available(iOS 9.3, *) {
                    switch AppleMusicClient.shared.authroizationStatus {
                    case .notDetermined:
                        AppleMusicClient.shared.connect(silent: false).start()
                    case .denied:
                        UIApplication.shared.openURL(URL(string: "app-settings:")!)
                    default:
                        break
                    }
                }
            }
        case .behavior:
            switch BehaviorRow(rawValue: indexPath.row)! {
            case .youTubeVideoQuality:
                let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                for action in YouTubeVideoQuality.buildAlertActions({ self.tableView.reloadData() }) {
                    actionSheet.addAction(action)
                }
                actionSheet.addAction(UIAlertAction(title: "Cancel".localize(), style: .cancel, handler: { action in }))
                present(actionSheet, animated: true, completion: {})
            case .notificationTime:
                let dateSelectionVC = RMDateSelectionViewController.dateSelection()
                dateSelectionVC?.selectButtonAction = { (controller, date) in
                    guard let d = date else { return }
                    let calendar = Calendar.current
                    let components: Set<Calendar.Component> = [Calendar.Component.hour, Calendar.Component.minute]
                    CloudAPIClient.notificationDateComponents = calendar.dateComponents(components, from: d as Date)
                    tableView.reloadData()
                    UpdateChecker().check(UIApplication.shared, completionHandler: nil)
                }
                dateSelectionVC?.cancelButtonAction = { controller in }
                dateSelectionVC?.nowButtonAction = { controller in
                    CloudAPIClient.notificationDateComponents = nil
                    self.tableView.reloadData()
                    dateSelectionVC?.dismiss(animated: true, completion: {})
                    UpdateChecker().check(UIApplication.shared, completionHandler: nil)
                }
                if let time = CloudAPIClient.notificationDateComponents {
                    let calendar = Calendar.current
                    dateSelectionVC?.datePicker.date = calendar.date(from: time as DateComponents)!
                }
                dateSelectionVC?.datePicker.datePickerMode = UIDatePickerMode.time
                dateSelectionVC?.datePicker.minuteInterval = UILocalNotification.notificationTimeMinutesInterval
                present(dateSelectionVC!, animated:true, completion:{})
            case .unlockEverything:
                appDelegate.paymentManager?.purchaseUnlockEverything()
            case .restorePurchase:
                appDelegate.paymentManager?.restorePurchase()
            }
        case .feedback:
            switch FeedbackRow(rawValue: indexPath.row)! {
            case .feedback:
                let vc = FeedbackWebViewController()
                navigationController?.pushViewController(vc, animated: true)
            case .rate:
                let appleId = "957250852";
                let url = URL(string: "itms-apps://itunes.apple.com/app/id\(appleId)")!
                UIApplication.shared.openURL(url)
            }
        case .other:
            switch OtherRow(rawValue: indexPath.row)! {
            case .about:
                let vc = IASKAppSettingsViewController()
                vc.showCreditsFooter = false
                navigationController?.pushViewController(vc, animated: true)
                vc.navigationItem.rightBarButtonItems = []
            case .tutorial:
                let vc = TutorialViewController()
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
}
