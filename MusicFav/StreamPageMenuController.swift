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

class StreamPageMenuController: UIViewController {
    var pageMenu:     CAPSPageMenu!
    var stream:       Stream!
    var streamLoader: StreamLoader!
    var unreadOnly:   Bool = true

    init(stream: Stream) {
        self.stream       = stream
        self.streamLoader = StreamLoader(stream: stream, unreadOnly: unreadOnly)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.toolbar.translucent       = false
        self.navigationController?.navigationBar.translucent = false

        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "playlist"),
            style: UIBarButtonItemStyle.Plain,
            target: self,
            action: "showPlaylist")
        navigationItem.title = stream.streamTitle

        var entryStream      = EntryStreamViewController(streamLoader: streamLoader)
        var playlistStream   = PlaylistStreamViewController(streamLoader: streamLoader)

        entryStream.title    = "Article".localize()
        playlistStream.title = "Playlist".localize()
        var controllerArray : [UIViewController] = [entryStream, playlistStream]
        var parameters: [String: AnyObject] = ["menuItemSeparatorWidth": 0.8,
                                          "useMenuLikeSegmentedControl": true,
                                    "menuItemSeparatorPercentageHeight": 0.8,
                                                           "menuHeight": 24,
                                            "scrollMenuBackgroundColor": UIColor.whiteColor(),
                                              "selectionIndicatorColor": ColorHelper.themeColor,
                                           "selectedMenuItemLabelColor": ColorHelper.themeColor,
                                         "unselectedMenuItemLabelColor": UIColor.grayColor(),
                                               "menuItemSeparatorColor": ColorHelper.lightGray,
                                              "bottomMenuHairlineColor": ColorHelper.lightGray,
                                                         "menuItemFont": UIFont.boldSystemFontOfSize(14)
                                        ]
        pageMenu = CAPSPageMenu(viewControllers: controllerArray,
                                          frame: CGRectMake(self.view.frame.origin.x,
                                                            self.view.frame.origin.y,
                                                            self.view.frame.width,
                                                            self.view.frame.height),
                                        options: parameters)
        self.view.addSubview(pageMenu.view)
        addChildViewController(pageMenu)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func showPlaylist() {
        let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        appDelegate.miniPlayerViewController?.mainViewController.showRightPanelAnimated(true)
    }
}
