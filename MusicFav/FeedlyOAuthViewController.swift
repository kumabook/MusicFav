//
//  FeedlyOAuthViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/21/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import LlamaKit
import NXOAuth2Client

protocol FeedlyOAuthViewDelegate: class {
    func onLoggedIn()
}

class FeedlyOAuthViewController: UIViewController, UIWebViewDelegate {
    var appDelegate:  AppDelegate     { get { return UIApplication.sharedApplication().delegate as AppDelegate } }
    var feedlyClient: FeedlyAPIClient { get { return FeedlyAPIClient.sharedInstance } }
    weak var delegate: FeedlyOAuthViewDelegate?

    @IBOutlet weak var loginWebView: UIWebView!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title:"close".localize(),
            style: UIBarButtonItemStyle.Plain,
            target: self,
            action: "close")
        self.loginWebView!.delegate = self
        setupOAuth2AccountStore()
        requestOAuth2Access()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func close() {
        self.navigationController?.dismissViewControllerAnimated(true, nil)
    }

    func setupOAuth2AccountStore() {
        NXOAuth2AccountStore.sharedStore().setClientID(FeedlyAPIClientConfig.clientId,
            secret: FeedlyAPIClientConfig.clientSecret,
            scope: NSSet(object:FeedlyAPIClientConfig.scopeUrl),
            authorizationURL: NSURL(string:FeedlyAPIClientConfig.authUrl),
            tokenURL: NSURL(string:FeedlyAPIClientConfig.tokenUrl),
            redirectURL: NSURL(string:FeedlyAPIClientConfig.redirectUrl),
            keyChainGroup: "Feedly",
            forAccountType: FeedlyAPIClientConfig.accountType)
        let dc = NSNotificationCenter.defaultCenter()
        dc.addObserverForName(NXOAuth2AccountStoreAccountsDidChangeNotification,
            object: NXOAuth2AccountStore.sharedStore(),
            queue: nil) { (notification) -> Void in
                if notification.userInfo != nil {
                    let account = notification.userInfo![NXOAuth2AccountStoreNewAccountUserInfoKey] as NXOAuth2Account
                    self.onLoggedIn(account)
                } else {
                    self.showAlert()
                }
        }
        dc.addObserverForName(NXOAuth2AccountStoreDidFailToRequestAccessNotification,
            object: NXOAuth2AccountStore.sharedStore(),
            queue: nil) { (notification) -> Void in
                self.showAlert()
        }
    }

    func showAlert() {
        UIAlertController.show(self, title: "Notice".localize(), message: "Login failed.", handler: { (action) -> Void in
            self.feedlyClient.clearAllAccount()
        })
    }
    
    func onLoggedIn(account: NXOAuth2Account) {
        feedlyClient.fetchProfile()
            .deliverOn(MainScheduler())
            .start(
                next: {profile in
                    self.feedlyClient.profile = profile
                },
                error: {error in
                    self.dismissViewControllerAnimated(true, completion: nil)
                },
                completed: {
                    self.dismissViewControllerAnimated(true, completion: nil)
                    self.delegate?.onLoggedIn()
                    self.appDelegate.didLogin()
            })
    }
    
    func requestOAuth2Access() {
        NXOAuth2AccountStore.sharedStore().requestAccessToAccountWithType(FeedlyAPIClientConfig.accountType, withPreparedAuthorizationURLHandler: { (preparedURL) -> Void in
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
