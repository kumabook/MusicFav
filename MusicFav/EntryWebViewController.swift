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
import DrawerController

class EntryWebViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, EntryMenuDelegate {
    let indicatorSize = 48
    var playlistButton:       UIBarButtonItem?
    var entryMenuButton:      UIBarButtonItem?
    var historyForwardButton: UIBarButtonItem?
    var historyBackButton:    UIBarButtonItem?

    var currentURL: URL?
    var indicator:  OnpuIndicatorView
    var webView:    WKWebView?
    var entry:      Entry
    var url:        URL = URL(string: "http://http://musicfav.github.io/")!
    var playlist:   Playlist?
    var entryMenu:  EntryMenu?

    init(entry: Entry, playlist: Playlist?) {
        self.entry     = entry
        self.playlist  = playlist
        self.indicator = OnpuIndicatorView(frame: CGRect(x: 0, y: 0, width: indicatorSize, height: indicatorSize), animation: .colorSwitch)
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
        view.insertSubview(webView!, at:0)
        view.addConstraints([
            NSLayoutConstraint(item: webView!,
                attribute: NSLayoutAttribute.width,
                relatedBy: NSLayoutRelation.equal,
                   toItem: view,
                attribute: NSLayoutAttribute.width,
               multiplier: 1.0,
                 constant: 0),
            NSLayoutConstraint(item: webView!,
                attribute: NSLayoutAttribute.height,
                relatedBy: NSLayoutRelation.equal,
                   toItem: view,
                attribute: NSLayoutAttribute.height,
               multiplier: 1.0,
                 constant: 0)
            ])
        
        webView!.allowsBackForwardNavigationGestures = true
        playlistButton        = UIBarButtonItem(image: UIImage(named: "playlist"),
                                                style: UIBarButtonItemStyle.plain,
                                               target: self,
                                               action: #selector(EntryWebViewController.showPlaylist))
        entryMenuButton       = UIBarButtonItem(image: UIImage(named: "entry_menu"),
                                                style: UIBarButtonItemStyle.plain,
                                               target: self,
                                               action: #selector(EntryWebViewController.showEntryMenu))
        historyForwardButton  = UIBarButtonItem(image: UIImage(named: "history_forward"),
                                                style: UIBarButtonItemStyle.plain,
                                               target: self,
                                               action: #selector(EntryWebViewController.historyForward))
        historyBackButton     = UIBarButtonItem(image: UIImage(named: "history_back"),
                                                style: UIBarButtonItemStyle.plain,
                                               target: self,
                                               action: #selector(EntryWebViewController.historyBack))
        navigationItem.rightBarButtonItems = [playlistButton!,
                                              entryMenuButton!,
                                              historyForwardButton!,
                                              historyBackButton!]
        loadEntryMenu()
        if let url = entry.url {
            loadURL(url as URL)
        }
        updateViews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
        webView?.navigationDelegate = self
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "MusicFav")
        webView?.configuration.userContentController.add(self, name: "MusicFav")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        entryMenu?.hide()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        webView?.navigationDelegate = nil
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "MusicFav")
    }

    func loadEntryMenu() {
        if let menu = entryMenu {
            menu.removeFromSuperview()
            menu.delegate = nil
        }
        entryMenu = EntryMenu(frame: view.frame, items: [.openWithSafari, .share, .favorite, .saveToFeedly ])
        entryMenu?.delegate = self
        view.addSubview(entryMenu!)
        entryMenu?.isHidden = true
    }

    func loadURL(_ url: URL) {
        let _ = webView?.load(URLRequest(url: url))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let body = message.body as? String {
            if message.name == "MusicFav" {
                let json: AnyObject? = try! JSONSerialization.jsonObject(with: body.data(using: String.Encoding.utf8)!, options: JSONSerialization.ReadingOptions.allowFragments) as AnyObject?
                
                let p = Playlist(json: JSON(json!))
                if p.tracks.count > 0 {
                    playlist = p
                    let appDelegate = UIApplication.shared.delegate as! AppDelegate
                    appDelegate.selectedPlaylist = p
                    appDelegate.miniPlayerViewController?.playlistTableViewController.updateNavbar()
                    appDelegate.miniPlayerViewController?.playlistTableViewController.tableView.reloadData()
                }
            }
        }
    }

    fileprivate func createWebView() -> WKWebView {
        let script = WKUserScript(source: getSource(), injectionTime: WKUserScriptInjectionTime.atDocumentEnd, forMainFrameOnly: false)
        let userContentController = WKUserContentController()
        userContentController.addUserScript(script)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController;
        return WKWebView(frame: view.bounds, configuration: configuration)
    }

    fileprivate func getSource() -> String {
        let bundle                  = Bundle.main
        let playlistifyPath: String = bundle.path(forResource: "playlistify-userscript", ofType: "js")!
        let mainPath:        String = bundle.path(forResource: "main", ofType: "js")!
        return (try! String(contentsOfFile: playlistifyPath)) + (try! String(contentsOfFile: mainPath))
    }

    func updateViews() {
        historyForwardButton!.isEnabled = webView!.canGoForward
        historyBackButton!.isEnabled    = webView!.canGoBack
    }

    func showPlaylist() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainViewController?.openDrawerSide(DrawerSide.right, animated: true, completion: nil)
    }

    func historyBack() {
        Logger.sendUIActionEvent(self, action: "goBack", label: "")
        let _ = webView?.goBack()
    }

    func historyForward() {
        Logger.sendUIActionEvent(self, action: "goForward", label: "")
        let _ = webView?.goForward()
    }

    func openWithSafari() {
        if let url = self.currentURL {
            UIApplication.shared.openURL(url)
        }
    }

    func share() {
        var sharingItems = [AnyObject]()
        if let entry = self.buildEntryWithCurrentPage() {
            if let title = entry.title { sharingItems.append(title as AnyObject) }
        } else {
            if let title = self.entry.title { sharingItems.append(title as AnyObject) }
        }
        if let url = self.currentURL {
            sharingItems.append(url as AnyObject)
        }
        let activityViewController = UIActivityViewController(activityItems: sharingItems, applicationActivities: nil)
        self.present(activityViewController, animated: true, completion: nil)
    }

    func favEntry() {
        Logger.sendUIActionEvent(self, action: "favEntry", label: "")
        var en: Entry
        if let e = buildEntryWithCurrentPage() {
            en = e
        } else {
            en = entry
        }
        if EntryStore.create(en) {
            let _ = MBProgressHUD.showCompletedHUDForView(self.navigationController!.view, animated: true, duration: 1.0) {
                self.navigationController?.dismiss(animated: true, completion: nil)
                return
            }
        } else {
            let ac = MusicFavError.entryAlreadyExists.alertController { (action) in }
            self.present(ac, animated: true, completion: nil)
        }
    }

    func saveToFeedly() {
        Logger.sendUIActionEvent(self, action: "saveToFeedly", label: "")
        let feedlyClient = CloudAPIClient.sharedInstance
        if CloudAPIClient.isLoggedIn {
            MBProgressHUD.showAdded(to: view, animated: true)
            let _ = feedlyClient.markEntriesAsSaved([entry.id], completionHandler: { response in
                MBProgressHUD.hide(for: self.view, animated:false)
                if let e = response.error {
                    let ac = CloudAPIClient.alertController(error: e, handler: { (action) in })
                    self.present(ac, animated: true, completion: nil)
                } else {
                    let _ = MBProgressHUD.showCompletedHUDForView(self.navigationController!.view, animated: true, duration: 1.0) {
                        self.navigationController?.dismiss(animated: true, completion: nil)
                        return
                    }
                }
            })
        } else {
            let vc = UINavigationController(rootViewController: FeedlyOAuthViewController())
            navigationController?.present(vc, animated: true, completion: {})
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        currentURL = webView.url
        indicator.center = webView.center
        view.addSubview(indicator)
        indicator.startAnimating()
    }

    internal func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        indicator.stopAnimating()
        indicator.removeFromSuperview()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        indicator.stopAnimating()
        indicator.removeFromSuperview()
        updateViews()
        if let url = currentURL, let entryURL = entry.url {
            if url == entryURL as URL {
                let _ = HistoryStore.add(entry)
            } else {
                if let en = buildEntryWithCurrentPage() {
                    let _ = HistoryStore.add(en)
                }
            }
        }
    }

    func buildEntryWithCurrentPage() -> Entry? {
        if let url = currentURL, let wv = webView {
            let en       = Entry(id: url.absoluteString)
            en.title     = wv.title
            en.author    = entry.author
            en.crawled   = Date().timestamp
            en.recrawled = Date().timestamp
            en.published = Date().timestamp
            en.alternate = [Link(href: url.absoluteString, type: "text/html", length: 0)]
            return en
        }
        return nil
    }

    func showEntryMenu() {
        if let menu = entryMenu {
            if menu.isHidden { menu.showWithNavigationBar(navigationController?.navigationBar) }
            else           { menu.hide() }
        }
    }

    // MARK: - EntryMenuDelegate

    func entryMenuSelected(_ item: EntryMenu.MenuItem) {
        switch item {
        case .openWithSafari: openWithSafari()
        case .share:          share()
        case .favorite:       favEntry()
        case .saveToFeedly:   saveToFeedly()
        }
    }
}
