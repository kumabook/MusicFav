//
//  NavigationBarScrollable.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 11/26/16.
//  Copyright © 2016 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import AMScrollingNavbar

protocol NavigationBarScrollable {
    func navigationBarFollowsToScrollView()
    func followScrollView(scrollingNavigationController: ScrollingNavigationController)
}

extension UITableViewController: NavigationBarScrollable {
    func navigationBarFollowsToScrollView() {
        guard let vc = navigationController as? ScrollingNavigationController else { return }
        followScrollView(scrollingNavigationController: vc)
    }
    func followScrollView(scrollingNavigationController: ScrollingNavigationController) {
        scrollingNavigationController.followScrollView(tableView, delay: 0.0)
    }
    func navigationBarStopsFollowingScrollView() {
        guard let vc = navigationController as? ScrollingNavigationController else { return }
        stopFollowingScrollView(scrollingNavigationController: vc)
    }
    func stopFollowingScrollView(scrollingNavigationController: ScrollingNavigationController) {
        scrollingNavigationController.stopFollowingScrollView()
    }
}

extension EntryWebViewController: NavigationBarScrollable {
    func navigationBarFollowsToScrollView() {
        guard let vc = navigationController as? ScrollingNavigationController else { return }
        followScrollView(scrollingNavigationController: vc)
    }
    func followScrollView(scrollingNavigationController: ScrollingNavigationController) {
        guard let scrollView = webView?.scrollView else { return }
        scrollingNavigationController.followScrollView(scrollView, delay: 50.0)
    }
    func navigationBarStopsFollowingScrollView() {
        guard let vc = navigationController as? ScrollingNavigationController else { return }
        stopFollowingScrollView(scrollingNavigationController: vc)
    }
    func stopFollowingScrollView(scrollingNavigationController: ScrollingNavigationController) {
        scrollingNavigationController.stopFollowingScrollView()
    }
}
