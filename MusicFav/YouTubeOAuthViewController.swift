//
//  YouTubeOAuthViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 9/5/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import FeedlyKit
import MusicFeeder
import ReactiveCocoa
import NXOAuth2Client
import SoundCloudKit

class YouTubeOAuthViewController: OAuthViewController {
    init() {
        super.init(clientId: YouTubeAPIClient.clientId,
               clientSecret: YouTubeAPIClient.clientSecret,
                      scope: YouTubeAPIClient.scope,
                    authUrl: YouTubeAPIClient.authUrl,
                   tokenUrl: YouTubeAPIClient.tokenUrl,
                redirectUrl: YouTubeAPIClient.redirectUrl,
                accountType: YouTubeAPIClient.accountType,
              keyChainGroup: YouTubeAPIClient.keyChainGroup)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func showAlert() {
        let _ = UIAlertController.show(self, title: "Notice".localize(), message: "Login failed.", handler: { (action) -> Void in
            YouTubeAPIClient.clearAllAccount()
        })
    }

    override func onLoggedIn(_ account: NXOAuth2Account) {
        super.onLoggedIn(account)
        self.appDelegate.reload()
    }
}
