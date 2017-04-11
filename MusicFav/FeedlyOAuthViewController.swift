//
//  FeedlyOAuthViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/21/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import FeedlyKit
import MusicFeeder
import ReactiveSwift
import NXOAuth2Client

class FeedlyOAuthViewController: OAuthViewController {
    var feedlyClient: CloudAPIClient { return CloudAPIClient.sharedInstance }

    init() {
        super.init(clientId: CloudAPIClient.clientId,
               clientSecret: CloudAPIClient.clientSecret,
                      scope: CloudAPIClient.scope,
                    authUrl: CloudAPIClient.sharedInstance.authUrl,
                   tokenUrl: CloudAPIClient.sharedInstance.tokenUrl,
                redirectUrl: CloudAPIClient.redirectUrl,
                accountType: CloudAPIClient.accountType,
              keyChainGroup: CloudAPIClient.keyChainGroup)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func showAlert() {
        let _ = UIAlertController.show(self, title: "Notice".localize(), message: "Login failed.", handler: { (action) -> Void in
            CloudAPIClient.logout()
        })
    }
    
    override func onLoggedIn(_ account: NXOAuth2Account) {
        feedlyClient.setAccessToken(account.accessToken.accessToken)
        feedlyClient.fetchProfile()
            .start(on: UIScheduler())
            .on(
                failed: {error in
                    self.showAlert()
            },
                completed: {
                    self.dismiss(animated: true, completion: nil)
                    self.delegate?.onLoggedIn(account)
                    self.appDelegate.didLogin()
            },
                value: {profile in
                    CloudAPIClient.login(profile: profile, token: account.accessToken.accessToken)
            }).start()
    }
}
