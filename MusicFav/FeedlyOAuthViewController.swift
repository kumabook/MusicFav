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
import ReactiveCocoa
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
        UIAlertController.show(self, title: "Notice".localize(), message: "Login failed.", handler: { (action) -> Void in
            CloudAPIClient.logout()
        })
    }
    
    override func onLoggedIn(account: NXOAuth2Account) {
        feedlyClient.setAccessToken(account.accessToken.accessToken)
        feedlyClient.fetchProfile()
            .startOn(UIScheduler())
            .on(
                next: {profile in
                    CloudAPIClient.login(profile, token: account.accessToken.accessToken)
                },
                failed: {error in
                    self.showAlert()
                },
                completed: {
                    self.dismissViewControllerAnimated(true, completion: nil)
                    self.delegate?.onLoggedIn(account)
                    self.appDelegate.didLogin()
            }).start()
    }
}
