//
//  StreamPageMenuControllerController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/4/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import PageMenu
import FeedlyKit
import MusicFeeder

class StreamPageMenuController: UIViewController {
    var pageMenu:     CAPSPageMenu!
    let stream:       Stream!
    let streamLoader: StreamLoader!
    weak var entryStreamViewController:    EntryStreamViewController?
    weak var playlistStreamViewController: PlaylistStreamViewController?

    init(stream: Stream) {
        self.stream       = stream
        self.streamLoader = StreamLoader(stream: stream)
        super.init(nibName: nil, bundle: nil)
    }

    required init(coder aDecoder: NSCoder) {
        self.stream       = DummyStream()
        self.streamLoader = StreamLoader(stream: stream)
        super.init(coder:aDecoder)
    }

    deinit {
        streamLoader.dispose()
    }

    override func viewDidLoad() {
        self.navigationController?.toolbar.translucent       = false
        self.navigationController?.navigationBar.translucent = false

        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "playlist"),
            style: UIBarButtonItemStyle.Plain,
            target: self,
            action: "showPlaylist")
        navigationItem.rightBarButtonItem!.accessibilityLabel = AccessibilityLabel.PlaylistMenuButton.s
        navigationItem.title = stream.streamTitle

        let entrySVC    = EntryStreamViewController(streamLoader: streamLoader)
        let playlistSVC = PlaylistStreamViewController(streamLoader: streamLoader)

        entrySVC.title    = "Article".localize()
        playlistSVC.title = "Playlist".localize()
        var controllerArray : [UIViewController] = [entrySVC, playlistSVC]
        var parameters: [CAPSPageMenuOption] = [
            .MenuItemSeparatorWidth(0.0),
            .UseMenuLikeSegmentedControl(true),
            .MenuItemSeparatorPercentageHeight(0.0),
            .MenuHeight(24),
            .ScrollMenuBackgroundColor(UIColor.whiteColor()),
            .SelectionIndicatorColor(UIColor.theme),
            .SelectedMenuItemLabelColor(UIColor.theme),
            .UnselectedMenuItemLabelColor(UIColor.grayColor()),
            .MenuItemSeparatorColor(UIColor.lightGray),
            .BottomMenuHairlineColor(UIColor.lightGray),
            .MenuItemFont(UIFont.boldSystemFontOfSize(14))
        ]
        pageMenu = CAPSPageMenu(viewControllers: controllerArray,
                                          frame: view.frame,
                                pageMenuOptions: parameters)
        pageMenu.view.accessibilityLabel = AccessibilityLabel.StreamPageMenu.s
        view.addSubview(pageMenu.view)
        addChildViewController(pageMenu)
        pageMenu.didMoveToParentViewController(self)
        super.viewDidLoad()
        entryStreamViewController    = entrySVC
        playlistStreamViewController = playlistSVC
        streamLoader.fetchEntries()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func showPlaylist() {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        appDelegate.miniPlayerViewController?.mainViewController.showRightPanelAnimated(true)
    }
}
