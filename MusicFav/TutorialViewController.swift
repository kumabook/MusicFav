//
//  TutorialViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/18/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import EAIntroView

class TutorialViewController: UIViewController, TutorialViewDelegate, FeedlyOAuthViewDelegate {
    var appDelegate: AppDelegate { return UIApplication.sharedApplication().delegate as AppDelegate }
    var tutorialView: TutorialView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.theme
        modalTransitionStyle = UIModalTransitionStyle.CrossDissolve
        tutorialView = TutorialView.tutorialView(view.frame, delegate: self)
        tutorialView.skipButton.hidden = true
        view.addSubview(tutorialView)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillAppear(animated: Bool) {
        navigationController?.navigationBarHidden = true
    }

    override func viewWillDisappear(animated: Bool) {
        navigationController?.navigationBarHidden = false
    }

    func close() {
        appDelegate.finishTutorial()
        if let nav = navigationController {
            nav.popViewControllerAnimated(true)
        } else {
            dismissViewControllerAnimated(true, completion: {})
        }
    }

    // MARK: - FeedlyOAuthViewDelegate

    func onLoggedIn() {
        close()
    }

    // MARK: - TutorialViewDelegate

    func tutorialLoginButtonTapped() {
        let oauthvc = FeedlyOAuthViewController()
        oauthvc.delegate = self
        let vc = UINavigationController(rootViewController: oauthvc)
        self.presentViewController(vc, animated: true, completion: {})
    }

    // MARK: - EAIntroDelegate

    func introDidFinish(introView: EAIntroView!) { close() }
    func intro(introView: EAIntroView!, pageAppeared page: EAIntroPage!, withIndex pageIndex: UInt) {
        tutorialView.skipButton.hidden = tutorialView.pages.count-1 != Int(pageIndex)
    }
    func intro(introView: EAIntroView!, pageStartScrolling page: EAIntroPage!, withIndex pageIndex: UInt) {}
    func intro(introView: EAIntroView!, pageEndScrolling page: EAIntroPage!, withIndex pageIndex: UInt) {}
}
