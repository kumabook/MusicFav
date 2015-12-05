//
//  SoundCloudOAuthViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/22/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import FeedlyKit
import MusicFeeder
import ReactiveCocoa
import NXOAuth2Client
import SoundCloudKit

class SoundCloudOAuthViewController: OAuthViewController {
    init() {
        super.init(clientId: SoundCloudKit.APIClient.clientId,
               clientSecret: SoundCloudKit.APIClient.clientSecret,
                      scope: SoundCloudKit.APIClient.scope,
                    authUrl: SoundCloudKit.APIClient.authUrl,
                   tokenUrl: SoundCloudKit.APIClient.tokenUrl,
                redirectUrl: SoundCloudKit.APIClient.redirectUrl,
                accountType: SoundCloudKit.APIClient.accountType,
              keyChainGroup: SoundCloudKit.APIClient.keyChainGroup)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func showAlert() {
        UIAlertController.show(self, title: "Notice".localize(), message: "Login failed.", handler: { (action) -> Void in
            SoundCloudKit.APIClient.accessToken = nil
            SoundCloudKit.APIClient.me = nil
            SoundCloudKit.APIClient.clearAllAccount()
        })
    }
    
    override func onLoggedIn(account: NXOAuth2Account) {
        super.onLoggedIn(account)
        SoundCloudKit.APIClient.accessToken = account.accessToken.accessToken
        SoundCloudKit.APIClient.sharedInstance.fetchMe().on(
            failed: { error in
                self.showAlert()
            }, next: { user in
                SoundCloudKit.APIClient.me = user
                self.dismissViewControllerAnimated(true, completion: nil)
                super.onLoggedIn(account)
                self.appDelegate.reload()
        }).start()
    }
}
