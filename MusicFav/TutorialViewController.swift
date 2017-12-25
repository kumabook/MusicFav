//
//  TutorialViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/18/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import EAIntroView
import NXOAuth2Client

class TutorialViewController: UIViewController, TutorialViewDelegate, OAuthViewDelegate {
    var appDelegate: AppDelegate { return UIApplication.shared.delegate as! AppDelegate }
    var tutorialView: TutorialView!

    deinit {}

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.theme
        modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        tutorialView = TutorialView.tutorialView(view.frame, delegate: self)
        tutorialView.skipButton.isHidden = true
        tutorialView.skipButton.addTarget(self, action: #selector(TutorialViewController.skipButtonTapped), for: UIControlEvents.touchUpInside)
        view.addSubview(tutorialView)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
        navigationController?.isNavigationBarHidden = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.isNavigationBarHidden = false
    }

    func close() {
        appDelegate.finishTutorial()
        if !appDelegate.didFinishSelectStream {
            appDelegate.showAddStreamMenuViewController()
        }
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true, completion: {})
        }
    }

    @objc func skipButtonTapped() {
        Logger.sendUIActionEvent(self, action: "skipButtonTapped", label: "")
    }

    // MARK: - FeedlyOAuthViewDelegate

    func onLoggedIn(_ account: NXOAuth2Account) {
        Logger.sendUIActionEvent(self, action: "onLoggedIn", label: "")
        close()
    }

    // MARK: - TutorialViewDelegate

    func tutorialLoginButtonTapped() {
        Logger.sendUIActionEvent(self, action: "tutorialLoginButtonTapped", label: "")
        let oauthvc = FeedlyOAuthViewController()
        oauthvc.delegate = self
        let vc = UINavigationController(rootViewController: oauthvc)
        self.present(vc, animated: true, completion: {})
    }

    // MARK: - EAIntroDelegate

    func introDidFinish(_ introView: EAIntroView!) { close() }
    func intro(_ introView: EAIntroView!, pageAppeared page: EAIntroPage!, with pageIndex: UInt) {
        tutorialView.skipButton.isHidden = tutorialView.pages.count-1 != Int(pageIndex)
    }
    func intro(_ introView: EAIntroView!, pageStartScrolling page: EAIntroPage!, with pageIndex: UInt) {}
    func intro(_ introView: EAIntroView!, pageEndScrolling page: EAIntroPage!, with pageIndex: UInt) {}
}
