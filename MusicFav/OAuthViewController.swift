//
//  OAuthWebViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2018/01/01.
//  Copyright © 2018 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import SoundCloudKit
import FeedlyKit
import UIKit
import OAuthSwift

class OAuthViewController: OAuthWebViewController {
    var targetURL: URL?
    let webView: UIWebView = UIWebView()
    weak var oauth: OAuthSwift?
    var statusBarHeight: CGFloat {
        return UIApplication.shared.statusBarFrame.height
    }

    init(oauth: OAuthSwift) {
        self.oauth = oauth
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(OAuthViewController.close))
        webView.frame = view.frame
        webView.scalesPageToFit = true
        webView.delegate = self
        view.addSubview(webView)
        loadAddressURL()
    }

    @objc func close() {
        dismissWebViewController()
    }

    override func doHandle(_ url: URL) {
        let nav = UINavigationController(rootViewController: self)
        AppDelegate.shared.coverViewController?.present(nav, animated: true)
    }

    override func dismissWebViewController() {
        navigationController?.dismiss(animated: true, completion: nil)
        oauth?.cancel()
    }

    override func handle(_ url: URL) {
        targetURL = url
        super.handle(url)
        self.loadAddressURL()
    }

    func loadAddressURL() {
        guard let url = targetURL else {
            return
        }
        let req = URLRequest(url: url)
        self.webView.loadRequest(req)
    }
}

// MARK: UINavigationBarDelegate
extension OAuthViewController: UINavigationBarDelegate {
    public func position(for bar: UIBarPositioning) -> UIBarPosition {
        return UIBarPosition.topAttached
    }
}

// MARK: delegate

extension OAuthWebViewController: UIWebViewDelegate {
    public func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        guard let url = request.url else { return true }
        if url.absoluteString.hasPrefix(APIClient.redirectUri) || url.absoluteString.hasPrefix(CloudAPIClient.redirectUrl) {
            OAuthSwift.handle(url: url)
            dismissWebViewController()
        }
        return true
    }
}
