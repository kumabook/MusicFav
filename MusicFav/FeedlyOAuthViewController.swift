//
//  FeedlyOAuthViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/21/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import FeedlyKit
import MusicFeeder
import ReactiveCocoa
import NXOAuth2Client

protocol FeedlyOAuthViewDelegate: class {
    func onLoggedIn()
}

class FeedlyOAuthViewController: UIViewController, UIWebViewDelegate {
    var appDelegate:  AppDelegate    { return UIApplication.sharedApplication().delegate as! AppDelegate }
    var feedlyClient: CloudAPIClient { return CloudAPIClient.sharedInstance }
    weak var delegate: FeedlyOAuthViewDelegate?
    var observers: [NSObjectProtocol]!

    var loginWebView: UIWebView!

    init() {
        super.init(nibName: nil, bundle: nil)
        observers = []
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        observers = []
    }
    
    deinit {}

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title:"Close".localize(),
                                                                style: UIBarButtonItemStyle.Plain,
                                                               target: self,
                                                               action: "close")
        loginWebView = UIWebView(frame: view.frame)
        view.addSubview(loginWebView)
        loginWebView.delegate = self
        setupOAuth2AccountStore()
        requestOAuth2Access()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
        addObservers()
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        removeObservers()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func close() {
        self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }

    func setupOAuth2AccountStore() {
        NXOAuth2AccountStore.sharedStore().setClientID(CloudAPIClient.clientId,
                                           secret: CloudAPIClient.clientSecret,
                                            scope: Set([CloudAPIClient.scopeUrl]),
                                 authorizationURL: NSURL(string: feedlyClient.authUrl),
                                         tokenURL: NSURL(string: feedlyClient.tokenUrl),
                                      redirectURL: NSURL(string: CloudAPIClient.redirectUrl),
                                    keyChainGroup: "Feedly",
                                   forAccountType: CloudAPIClient.accountType)
            }

    func addObservers() {
        let dc = NSNotificationCenter.defaultCenter()
        observers.append(dc.addObserverForName(NXOAuth2AccountStoreAccountsDidChangeNotification,
            object: NXOAuth2AccountStore.sharedStore(),
            queue: nil) { (notification) -> Void in
                if notification.userInfo != nil {
                    let account = notification.userInfo![NXOAuth2AccountStoreNewAccountUserInfoKey] as! NXOAuth2Account
                    self.onLoggedIn(account)
                } else {
                    self.showAlert()
                }
        })
        observers.append(dc.addObserverForName(NXOAuth2AccountStoreDidFailToRequestAccessNotification,
            object: NXOAuth2AccountStore.sharedStore(),
            queue: nil) { (notification) -> Void in
                self.showAlert()
        })
    }

    func removeObservers() {
        let dc = NSNotificationCenter.defaultCenter()
        for observer in observers {
            dc.removeObserver(observer)
        }
        observers = []
    }

    func showAlert() {
        UIAlertController.show(self, title: "Notice".localize(), message: "Login failed.", handler: { (action) -> Void in
            CloudAPIClient.logout()
        })
    }
    
    func onLoggedIn(account: NXOAuth2Account) {
        feedlyClient.setAccessToken(account.accessToken.accessToken)
        feedlyClient.fetchProfile()
            |> startOn(UIScheduler())
            |> start(
                next: {profile in
                    CloudAPIClient.login(profile, token: account.accessToken.accessToken)
                },
                error: {error in
                    self.showAlert()
                },
                completed: {
                    self.dismissViewControllerAnimated(true, completion: nil)
                    self.delegate?.onLoggedIn()
                    self.appDelegate.didLogin()
            })
    }
    
    func requestOAuth2Access() {
        let store: AnyObject! = NXOAuth2AccountStore.sharedStore()
        store.requestAccessToAccountWithType(CloudAPIClient.accountType, withPreparedAuthorizationURLHandler: { (preparedURL) -> Void in
            self.loginWebView.loadRequest(NSURLRequest(URL: preparedURL))
        })
    }
    
    // MARK: - UIWebViewDelegate
    
    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        if NXOAuth2AccountStore.sharedStore().handleRedirectURL(request.URL) {
            return false
        }
        return true
    }
}
