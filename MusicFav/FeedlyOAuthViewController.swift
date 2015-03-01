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

class FeedlyOAuthViewController: UIViewController, UIWebViewDelegate {

    @IBOutlet weak var loginWebView: UIWebView!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title:"close",
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
                    println("hasLoggined")
                    let account = notification.userInfo![NXOAuth2AccountStoreNewAccountUserInfoKey] as NXOAuth2Account
                    self.onLoggedIn(account)
                } else {
                    print("not")
                }
        }
        dc.addObserverForName(NXOAuth2AccountStoreDidFailToRequestAccessNotification,
            object: NXOAuth2AccountStore.sharedStore(),
            queue: nil) { (notification) -> Void in
                println("Fail")
        }
    }
    
    func onLoggedIn(account: NXOAuth2Account) {
        let client = FeedlyAPIClient.sharedInstance
        client.fetchProfile()
            .deliverOn(MainScheduler())
            .start(
                next: {profile in
                    println(profile.id)
                    client.profile = profile
                },
                error: {error in
                    self.dismissViewControllerAnimated(true, completion: nil)
                },
                completed: {
                    self.dismissViewControllerAnimated(true, completion: nil)
            })
    }
    
    func getFeedlyAccount() -> NXOAuth2Account? {
        let store = NXOAuth2AccountStore.sharedStore() as NXOAuth2AccountStore
        for account in store.accounts as [NXOAuth2Account] {
            println("account \(account)")
            println("account \(account.identifier)")
            if account.accountType == "Feedly" {
                //                return account
            }
            store.removeAccount(account)
        }
        return nil
    }
    
    func requestOAuth2Access() {
        NXOAuth2AccountStore.sharedStore().requestAccessToAccountWithType(FeedlyAPIClientConfig.accountType, withPreparedAuthorizationURLHandler: { (preparedURL) -> Void in
            println(preparedURL)
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
