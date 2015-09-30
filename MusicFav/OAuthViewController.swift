//
//  OAuthViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 7/12/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

import UIKit
import ReactiveCocoa
import NXOAuth2Client
import MBProgressHUD

protocol OAuthViewDelegate: class {
    func onLoggedIn(account: NXOAuth2Account)
}

class OAuthViewController: UIViewController, UIWebViewDelegate {
    var appDelegate:  AppDelegate    { return UIApplication.sharedApplication().delegate as! AppDelegate }
    weak var delegate: OAuthViewDelegate?
    var observers: [NSObjectProtocol]!

    var loginWebView: UIWebView!

    let clientId:      String!
    let clientSecret:  String!
    let scope:         Set<String>!
    let authUrl:       String!
    let tokenUrl:      String!
    let redirectUrl:   String!
    let accountType:   String!
    let keyChainGroup: String!

    init(clientId: String, clientSecret: String, scope: Set<String>, authUrl: String, tokenUrl: String, redirectUrl: String, accountType: String, keyChainGroup: String) {
        self.clientId      = clientId
        self.clientSecret  = clientSecret
        self.scope         = scope
        self.authUrl       = authUrl
        self.tokenUrl      = tokenUrl
        self.redirectUrl   = redirectUrl
        self.accountType   = accountType
        self.keyChainGroup = keyChainGroup
        super.init(nibName: nil, bundle: nil)
        observers = []
    }

    required init?(coder aDecoder: NSCoder) {
        self.clientId      = nil
        self.clientSecret  = nil
        self.scope         = nil
        self.authUrl       = nil
        self.tokenUrl      = nil
        self.redirectUrl   = nil
        self.accountType   = nil
        self.keyChainGroup = nil
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
        cleanOAuth2AccountStore()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func close() {
        if self.navigationController?.childViewControllers.count == 1 {
            self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
        } else {
            self.navigationController?.popViewControllerAnimated(true)
        }
    }

    func setupOAuth2AccountStore() {
        NXOAuth2AccountStore.sharedStore().setClientID(clientId,
                                               secret: clientSecret,
                                                scope: scope,
                                     authorizationURL: NSURL(string: authUrl),
                                             tokenURL: NSURL(string: tokenUrl),
                                          redirectURL: NSURL(string: redirectUrl),
                                        keyChainGroup: keyChainGroup,
                                       forAccountType: accountType)
    }

    func cleanOAuth2AccountStore() {
        NXOAuth2AccountStore.sharedStore().setClientID("",
                                               secret: "",
                                                scope: scope,
                                     authorizationURL: NSURL(string: "http://dummy.com"),
                                             tokenURL: NSURL(string: "http://dummy.com"),
                                          redirectURL: NSURL(string: "http://dummy.com"),
                                        keyChainGroup: "",
                                       forAccountType: accountType)
    }

    func addObservers() {
        let dc = NSNotificationCenter.defaultCenter()
        observers.append(dc.addObserverForName(NXOAuth2AccountStoreAccountsDidChangeNotification,
            object: NXOAuth2AccountStore.sharedStore(),
            queue: nil) { (notification) -> Void in
                if let account = notification.userInfo?[NXOAuth2AccountStoreNewAccountUserInfoKey] as? NXOAuth2Account
                    where account.accountType == self.accountType {
                        self.onLoggedIn(account)
                }
            })
        observers.append(dc.addObserverForName(NXOAuth2AccountStoreDidFailToRequestAccessNotification,
            object: NXOAuth2AccountStore.sharedStore(),
            queue: nil) { (notification) -> Void in
                if let type = notification.userInfo?[kNXOAuth2AccountStoreAccountType] as? String where type == self.accountType {
                    self.showAlert()
                }
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
        })
    }

    func onLoggedIn(account: NXOAuth2Account) {
        delegate?.onLoggedIn(account)
        close()
    }

    func requestOAuth2Access() {
        let store: AnyObject! = NXOAuth2AccountStore.sharedStore()
        store.requestAccessToAccountWithType(accountType, withPreparedAuthorizationURLHandler: { (preparedURL) -> Void in
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

    func webViewDidStartLoad(webView: UIWebView) {
        MBProgressHUD.showHUDAddedTo(view, animated: true)
    }

    func webViewDidFinishLoad(webView: UIWebView) {
        MBProgressHUD.hideAllHUDsForView(view, animated: true)
    }

    func webView(webView: UIWebView, didFailLoadWithError error: NSError?) {
        MBProgressHUD.hideAllHUDsForView(view, animated: true)
    }
}
