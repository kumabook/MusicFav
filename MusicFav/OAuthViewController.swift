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
    func onLoggedIn(_ account: NXOAuth2Account)
}

class OAuthViewController: UIViewController, UIWebViewDelegate {
    var appDelegate:  AppDelegate    { return UIApplication.shared.delegate as! AppDelegate }
    weak var delegate: OAuthViewDelegate?
    var observers: [NSObjectProtocol]!

    var loginWebView: UIWebView!
    var progressHUD: MBProgressHUD?

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
                                                                style: UIBarButtonItemStyle.plain,
                                                               target: self,
                                                               action: #selector(OAuthViewController.close))
        loginWebView = UIWebView(frame: view.frame)
        view.addSubview(loginWebView)
        loginWebView.delegate = self
        setupOAuth2AccountStore()
        requestOAuth2Access()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
        addObservers()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeObservers()
        cleanOAuth2AccountStore()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func close() {
        if self.navigationController?.childViewControllers.count == 1 {
            self.navigationController?.dismiss(animated: true, completion: nil)
        } else {
           let _ =  self.navigationController?.popViewController(animated: true)
        }
    }

    func setupOAuth2AccountStore() {
        (NXOAuth2AccountStore.sharedStore() as AnyObject).setClientID(clientId,
                                               secret: clientSecret,
                                                scope: scope,
                                     authorizationURL: URL(string: authUrl),
                                             tokenURL: URL(string: tokenUrl),
                                          redirectURL: URL(string: redirectUrl),
                                        keyChainGroup: keyChainGroup,
                                       forAccountType: accountType)
    }

    func cleanOAuth2AccountStore() {
        (NXOAuth2AccountStore.sharedStore() as AnyObject).setClientID("",
                                               secret: "",
                                                scope: scope,
                                     authorizationURL: URL(string: "http://dummy.com"),
                                             tokenURL: URL(string: "http://dummy.com"),
                                          redirectURL: URL(string: "http://dummy.com"),
                                        keyChainGroup: "",
                                       forAccountType: accountType)
    }

    func addObservers() {
        let dc = NotificationCenter.default
        observers.append(dc.addObserver(forName: NSNotification.Name.NXOAuth2AccountStoreAccountsDidChange,
            object: NXOAuth2AccountStore.sharedStore(),
            queue: nil) { (notification) -> Void in
                if let account = notification.userInfo?[NXOAuth2AccountStoreNewAccountUserInfoKey] as? NXOAuth2Account, account.accountType == self.accountType {
                        self.onLoggedIn(account)
                }
            })
        observers.append(dc.addObserver(forName: NSNotification.Name.NXOAuth2AccountStoreDidFailToRequestAccess,
            object: NXOAuth2AccountStore.sharedStore(),
            queue: nil) { (notification) -> Void in
                if let type = notification.userInfo?[kNXOAuth2AccountStoreAccountType] as? String, type == self.accountType {
                    self.showAlert()
                }
            })
    }

    func removeObservers() {
        let dc = NotificationCenter.default
        for observer in observers {
            dc.removeObserver(observer)
        }
        observers = []
    }

    func showAlert() {
        let _ = UIAlertController.show(self, title: "Notice".localize(), message: "Login failed.", handler: { (action) -> Void in
        })
    }

    func onLoggedIn(_ account: NXOAuth2Account) {
        delegate?.onLoggedIn(account)
        close()
    }

    func requestOAuth2Access() {
        let store: AnyObject! = NXOAuth2AccountStore.sharedStore() as AnyObject!
        store.requestAccessToAccount(withType: accountType, withPreparedAuthorizationURLHandler: { (preparedURL) -> Void in
            self.loginWebView.loadRequest(URLRequest(url: preparedURL!))
        })
    }

    // MARK: - UIWebViewDelegate

    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        if (NXOAuth2AccountStore.sharedStore() as AnyObject).handleRedirectURL(request.url) {
            return false
        }
        return true
    }

    func webViewDidStartLoad(_ webView: UIWebView) {
        progressHUD = MBProgressHUD.showAdded(to: view, animated: true)
    }

    func webViewDidFinishLoad(_ webView: UIWebView) {
        progressHUD?.hide(animated: true)
        progressHUD = nil
    }

    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        progressHUD?.hide(animated: true)
        progressHUD = nil
    }
}
