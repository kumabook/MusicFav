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

    override func viewDidLoad() {
        super.viewDidLoad()

        self.webView.frame = UIScreen.main.bounds
        self.webView.scalesPageToFit = true
        self.webView.delegate = self
        self.view.addSubview(self.webView)
        loadAddressURL()
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

// MARK: delegate

extension OAuthWebViewController: UIWebViewDelegate {
    public func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        guard let url = request.url else { return true }
        if url.absoluteString.hasPrefix(APIClient.redirectUri) || url.absoluteString.hasPrefix(CloudAPIClient.redirectUrl) {
            OAuthSwift.handle(url: url)
            self.dismissWebViewController()
        }
        return true
    }
}
