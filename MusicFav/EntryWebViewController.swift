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
import MusicFeeder
import MBProgressHUD

class EntryWebViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    let indicatorSize = 48
    var playlistButton:       UIBarButtonItem?
    var favEntryButton:       UIBarButtonItem?
    var historyForwardButton: UIBarButtonItem?
    var historyBackButton:    UIBarButtonItem?

    var currentURL: NSURL?
    var indicator:  OnpuIndicatorView
    var webView:    WKWebView?
    var entry:      Entry
    var url:        NSURL = NSURL()
    var playlist:   Playlist?

    init(entry: Entry, playlist: Playlist?) {
        self.entry     = entry
        self.playlist  = playlist
        self.indicator = OnpuIndicatorView(frame: CGRect(x: 0, y: 0, width: indicatorSize, height: indicatorSize), animation: .ColorSwitch)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {}

    override func viewDidLoad() {
        super.viewDidLoad()
        webView = createWebView()
        webView!.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(webView!, atIndex:0)
        view.addConstraints([
            NSLayoutConstraint(item: webView!,
                attribute: NSLayoutAttribute.Width,
                relatedBy: NSLayoutRelation.Equal,
                   toItem: view,
                attribute: NSLayoutAttribute.Width,
               multiplier: 1.0,
                 constant: 0),
            NSLayoutConstraint(item: webView!,
                attribute: NSLayoutAttribute.Height,
                relatedBy: NSLayoutRelation.Equal,
                   toItem: view,
                attribute: NSLayoutAttribute.Height,
               multiplier: 1.0,
                 constant: 0)
            ])
        
        webView!.allowsBackForwardNavigationGestures = true
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

        navigationItem.rightBarButtonItems = [playlistButton!,
                                              favEntryButton!,
                                              historyForwardButton!,
                                              historyBackButton!]

        if let url = entry.url {
            loadURL(url)
        }
        updateViews()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
        webView?.navigationDelegate = self
        webView?.configuration.userContentController.removeScriptMessageHandlerForName("MusicFav")
        webView?.configuration.userContentController.addScriptMessageHandler(self, name: "MusicFav")
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        webView?.navigationDelegate = nil
        webView?.configuration.userContentController.removeScriptMessageHandlerForName("MusicFav")
    }

    func loadURL(url: NSURL) {
        currentURL = url
        webView?.loadRequest(NSURLRequest(URL: url))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
        if let body = message.body as? String {
            if message.name == "MusicFav" {
                let json: AnyObject? = try? NSJSONSerialization.JSONObjectWithData(body.dataUsingEncoding(NSUTF8StringEncoding)!, options: NSJSONReadingOptions.AllowFragments)
                
                let p = Playlist(json: JSON(json!))
                if p.tracks.count > 0 {
                    playlist = p
                    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
                    appDelegate.selectedPlaylist = p
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
        return WKWebView(frame: view.bounds, configuration: configuration)
    }

    private func getSource() -> String {
        let bundle                  = NSBundle.mainBundle()
        let playlistifyPath: String = bundle.pathForResource("playlistify-userscript", ofType: "js")!
        let mainPath:        String = bundle.pathForResource("main", ofType: "js")!
        return (try! String(contentsOfFile: playlistifyPath)) + (try! String(contentsOfFile: mainPath))
    }

    func updateViews() {
        historyForwardButton!.enabled = webView!.canGoForward
        historyBackButton!.enabled    = webView!.canGoBack
    }

    func showPlaylist() {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        appDelegate.mainViewController?.showRightPanelAnimated(true)
    }

    func historyBack() {
        Logger.sendUIActionEvent(self, action: "goBack", label: "")
        webView?.goBack()
    }

    func historyForward() {
        Logger.sendUIActionEvent(self, action: "goForward", label: "")
        webView?.goForward()
    }

    func favEntry() {
        Logger.sendUIActionEvent(self, action: "favEntry", label: "")
        let feedlyClient = CloudAPIClient.sharedInstance
        if CloudAPIClient.isLoggedIn {
            MBProgressHUD.showHUDAddedTo(view, animated: true)
            feedlyClient.markEntriesAsSaved([entry.id], completionHandler: { (req, res, result) -> Void in
                MBProgressHUD.hideHUDForView(self.view, animated:false)
                if let e = result.error {
                    let ac = CloudAPIClient.alertController(error: e, handler: { (action) in })
                    self.presentViewController(ac, animated: true, completion: nil)
                } else {
                    MBProgressHUD.showCompletedHUDForView(self.navigationController!.view, animated: true, duration: 1.0) {
                        self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
                        return
                    }
                }
            })
        } else {
            var en: Entry
            if let e = buildEntryWithCurrentPage() {
                en = e
            } else {
                en = entry
            }
            if EntryStore.create(en) {
                MBProgressHUD.showCompletedHUDForView(self.navigationController!.view, animated: true, duration: 1.0) {
                    self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
                    return
                }
            } else {
                let ac = Error.EntryAlreadyExists.alertController { (action) in }
                self.presentViewController(ac, animated: true, completion: nil)
            }
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        indicator.center = webView.center
        view.addSubview(indicator)
        indicator.startAnimating()
    }

    func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) {
        indicator.stopAnimating()
        indicator.removeFromSuperview()
    }

    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        indicator.stopAnimating()
        indicator.removeFromSuperview()
        updateViews()
        if let currentURL = webView.URL, entryURL = entry.url {
            if currentURL == entryURL {
                EntryHistoryStore.add(entry)
            } else {
                if let en = buildEntryWithCurrentPage() {
                    EntryHistoryStore.add(en)
                }
            }
        }
    }

    func buildEntryWithCurrentPage() -> Entry? {
        if let wv = webView, url = wv.URL {
            let en       = Entry(id: url.absoluteString)
            en.title     = wv.title
            en.author    = entry.author
            en.crawled   = NSDate().timestamp
            en.recrawled = NSDate().timestamp
            en.published = NSDate().timestamp
            en.alternate = [Link(href: url.absoluteString, type: "text/html", length: 0)]
            return en
        }
        return nil
    }
}
