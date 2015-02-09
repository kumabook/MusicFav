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

class EntryWebViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    var playlistButton:       UIBarButtonItem?
    var favEntryButton:       UIBarButtonItem?
    var historyForwardButton: UIBarButtonItem?
    var historyBackButton:    UIBarButtonItem?

    var currentURL: NSURL?
    var webView:    WKWebView?
    var url:        NSURL = NSURL()
    var playlist:   Playlist?
    
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
        
        self.webView!.navigationDelegate                  = self
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

        if let url = currentURL {
            self.loadURL(currentURL!)
        }
        updateViews()
    }

    func loadURL(url: NSURL) {
        currentURL = url
        if let webView = self.webView {
            println("load \(currentURL)")
            self.webView!.loadRequest(NSURLRequest(URL: url))
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
        println(message.body)
        if let body = message.body as? String {
            if message.name == "MusicFav" {
                let error: NSError? = nil
                let json: AnyObject? = NSJSONSerialization.JSONObjectWithData(body.dataUsingEncoding(NSUTF8StringEncoding)!, options: NSJSONReadingOptions.AllowFragments, error: nil)
                
                let playlist = Playlist(json: JSON(json!))
                if playlist.tracks.count > 0 {
                    self.playlist = playlist
                    let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
                    appDelegate.readingPlaylist = self.playlist!
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
        userContentController.addScriptMessageHandler(self, name: "MusicFav")
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
        let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        appDelegate.miniPlayerViewController?.mainViewController.showRightPanelAnimated(true)
    }

    func historyBack() {
        webView?.goBack()
    }
    
    func historyForward() {
        webView?.goForward()
    }
    
    func favEntry() {
        //TODO
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) {
        print("didFailNavigation")
    }
    
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        updateViews()
    }

}
