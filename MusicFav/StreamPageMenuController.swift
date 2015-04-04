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
    var pageMenu : CAPSPageMenu!
    var stream: Stream!
    init(stream: Stream) {
        self.stream = stream
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

        var entryStream      = EntryStreamViewController(stream: stream)
        var playlistStream   = PlaylistStreamViewController()
        entryStream.title    = "Entry View"
        playlistStream.title = "Playlist View"
        var controllerArray : [UIViewController] = [entryStream, playlistStream]
        var parameters: [String: AnyObject] = ["menuItemSeparatorWidth": 0.8,
                                          "useMenuLikeSegmentedControl": true,
                                    "menuItemSeparatorPercentageHeight": 0.8,
                                                           "menuHeight": 30,
                                            "scrollMenuBackgroundColor": ColorHelper.themeColorLight,
                                              "selectionIndicatorColor": ColorHelper.greenColor,
                                           "selectedMenuItemLabelColor": UIColor.whiteColor(),
                                         "unselectedMenuItemLabelColor": ColorHelper.lightGray,
                                               "menuItemSeparatorColor": UIColor.whiteColor()
//                                              "bottomMenuHairlineColor": UIColor.blueColor()
                                        ]
        
        pageMenu = CAPSPageMenu(viewControllers: controllerArray,
                                          frame: CGRectMake(self.view.frame.origin.x,
                                                            self.view.frame.origin.y,
                                                            self.view.frame.width,
                                                            self.view.frame.height),
                                        options: parameters)
        self.view.addSubview(pageMenu.view)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func showPlaylist() {
        let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        appDelegate.miniPlayerViewController?.mainViewController.showRightPanelAnimated(true)
    }
}
