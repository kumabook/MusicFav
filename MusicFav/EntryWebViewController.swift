//
//  EntryWebViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/23/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import WebKit
import SwiftyJSON
import FeedlyKit
import MBProgressHUD

class EntryWebViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    var playlistButton:       UIBarButtonItem?
    var favEntryButton:       UIBarButtonItem?
    var historyForwardButton: UIBarButtonItem?
    var historyBackButton:    UIBarButtonItem?
    var HUD:                  MBProgressHUD!

    var currentURL: NSURL?
    var webView:    WKWebView?
    var entry:      Entry
    var url:        NSURL = NSURL()
    var playlist:   Playlist?

    init(entry: Entry, playlist: Playlist?) {
        self.entry    = entry
        self.playlist = playlist
        super.init(nibName: nil, bundle: nil)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {}

    override func viewDidLoad() {
        super.viewDidLoad()
        self.webView = createWebView()
        self.webView!.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.view.insertSubview(self.webView!, atIndex:0)
        self.view.addConstraints([
            NSLayoutConstraint(item: self.webView!,
                attribute: NSLayoutAttribute.Width,
                relatedBy: NSLayoutRelation.Equal,
                toItem: self.view,
                attribute: NSLayoutAttribute.Width,
                multiplier: 1.0,
                constant: 0),
            NSLayoutConstraint(item: self.webView!,
                attribute: NSLayoutAttribute.Height,
                relatedBy: NSLayoutRelation.Equal,
                toItem: self.view,
                attribute: NSLayoutAttribute.Height,
                multiplier: 1.0,
                constant: 0)
            ])
        
        self.webView!.allowsBackForwardNavigationGestures = true
        playlistButton        = UIBarButtonItem(image: UIImage(named: "playlist"),
                                                style: UIBarButtonItemStyle.Plain,
                                               target: self,
                                               action: "showPlaylist")
        favEntryButton        = UIBarButtonItem(image: UIImage(named: "fav_entry"),
                                                style: UIBarButtonItemStyle.Plain,
                                               target: self,
                                               action: "favEntry")
        historyForwardButton  = UIBarButtonItem(image: UIImage(named: "history_forward"),
                                                style: UIBarButtonItemStyle.Plain,
                                               target: self,
                                               action: "historyForward")
        historyBackButton     = UIBarButtonItem(image: UIImage(named: "history_back"),
                                                style: UIBarButtonItemStyle.Plain,
                                               target: self,
                                               action: "historyBack")

        self.navigationItem.rightBarButtonItems = [playlistButton!,
                                                   favEntryButton!,
                                                   historyForwardButton!,
                                                   historyBackButton!]
        HUD = MBProgressHUD.createCompletedHUD(self.view)
        navigationController?.view.addSubview(HUD)

        if let url = entry.url {
            self.loadURL(url)
        }
        updateViews()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        webView!.navigationDelegate = self
        webView!.configuration.userContentController.addScriptMessageHandler(self, name: "MusicFav")
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        webView!.navigationDelegate = nil
        webView!.configuration.userContentController.removeScriptMessageHandlerForName("MusicFav")
    }

    func loadURL(url: NSURL) {
        currentURL = url
        if let webView = self.webView {
            webView.loadRequest(NSURLRequest(URL: url))
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
        if let body = message.body as? String {
            if message.name == "MusicFav" {
                let error: NSError? = nil
                let json: AnyObject? = NSJSONSerialization.JSONObjectWithData(body.dataUsingEncoding(NSUTF8StringEncoding)!, options: NSJSONReadingOptions.AllowFragments, error: nil)
                
                let playlist = Playlist(json: JSON(json!))
                if playlist.tracks.count > 0 {
                    self.playlist = playlist
                    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
                    appDelegate.selectedPlaylist = self.playlist!
                    appDelegate.miniPlayerViewController?.playlistTableViewController.updateNavbar()
                    appDelegate.miniPlayerViewController?.playlistTableViewController.tableView.reloadData()
                }
            }
        }
    }
    private func createWebView() -> WKWebView {
        let script = WKUserScript(source: getSource(), injectionTime: WKUserScriptInjectionTime.AtDocumentEnd, forMainFrameOnly: false)
        let userContentController = WKUserContentController()
        userContentController.addUserScript(script)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController;
        return WKWebView(frame: self.view.bounds, configuration: configuration)
    }
    
    private func getSource() -> String {
        let bundle = NSBundle.mainBundle()
        let playlistifyPath: String = bundle.pathForResource("playlistify-userscript", ofType: "js")!
        let mainPath:        String = bundle.pathForResource("main", ofType: "js")!
        let source = String(contentsOfFile: playlistifyPath)! + String(contentsOfFile: mainPath)!
        return source
    }
    
    func updateViews() {
        historyForwardButton!.enabled = webView!.canGoForward
        historyBackButton!.enabled    = webView!.canGoBack
    }
    
    func showPlaylist() {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        appDelegate.miniPlayerViewController?.mainViewController.showRightPanelAnimated(true)
    }

    func historyBack() {
        webView?.goBack()
    }
    
    func historyForward() {
        webView?.goForward()
    }
    
    func favEntry() {
        let feedlyClient = CloudAPIClient.sharedInstance
        if feedlyClient.isLoggedIn {
            MBProgressHUD.showHUDAddedTo(view, animated: true)
            feedlyClient.markEntriesAsSaved([entry.id], completionHandler: { (req, res, error) -> Void in
                MBProgressHUD.hideHUDForView(self.view, animated:false)
                if let e = error {
                    let ac = CloudAPIClient.alertController(error: e, handler: { (action) in })
                    self.presentViewController(ac, animated: true, completion: nil)
                } else {
                    self.HUD.show(true , duration: 1.0, after: { () -> Void in
                        self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
                        return
                    })
                }
            })
        } else {
            let title   = "Notice".localize()
            let message = "You can mark article as saved after login. Please login from left top setting menu.".localize()
            UIAlertController.show(self, title: title, message: message, handler: { (action) in })
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) {
    }
    
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        updateViews()
    }

}
