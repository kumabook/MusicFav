//
//  TutorialView.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/19/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import EAIntroView

protocol TutorialViewDelegate: EAIntroDelegate {
    func tutorialLoginButtonTapped()
}

class TutorialView: EAIntroView {
    class func tutorialView(frame: CGRect, delegate: TutorialViewDelegate?) -> TutorialView {
        let menuPage     = capturePage(frame, title: String.tutorialString("menu_page_title"),
                                               desc: String.tutorialString("menu_page_desc"),
                                            bgColor: UIColor.theme,
                                          imageName: "menu_cap")
        let streamPage   = capturePage(frame, title: String.tutorialString("stream_page_title"),
                                               desc: String.tutorialString("stream_page_desc"),
                                            bgColor: UIColor.theme,
                                          imageName: "stream_cap")
        let playlistPage = capturePage(frame, title: String.tutorialString("playlist_page_title"),
                                               desc: String.tutorialString("playlist_page_desc"),
                                            bgColor: UIColor.theme,
                                          imageName: "playlist_cap")
        let playerPage   = capturePage(frame, title: String.tutorialString("player_page_title"),
                                               desc: String.tutorialString("player_page_desc"),
                                            bgColor: UIColor.theme,
                                          imageName: "player_cap")
        var pages: [EAIntroPage] = [firstPage(frame),
                                    streamPage,
                                    playlistPage,
                                    playerPage,
                                    menuPage,
            lastPage(frame, delegate: delegate)]
        let tutorialView = TutorialView(frame: frame, andPages: pages)
        tutorialView.delegate = delegate
        return tutorialView
    }

    class func firstPage(frame: CGRect) -> EAIntroPage {
        let page = EAIntroPage()
        page.title          = String.tutorialString("first_page_title")
        page.titleFont      = UIFont.boldSystemFontOfSize(32)
        page.titlePositionY = frame.height * 0.6
        page.titleIconView  = UIImageView(image: UIImage(named: "note"))
        page.desc           = String.tutorialString("first_page_desc")
        page.descFont       = UIFont.systemFontOfSize(24)
        page.descPositionY  = frame.height * 0.4
        page.bgColor        = UIColor.theme
        return page
    }

    class func capturePage(frame: CGRect, title: String, desc: String, bgColor: UIColor, imageName: String) -> EAIntroPage {
        let height = frame.height
        let width  = frame.width
        let deviceType = DeviceType.from(device: UIDevice.currentDevice())

        let descLabel           = UILabel(frame: CGRect(x: width*0.1, y: height*0.68,
            width: width*0.8, height: height*0.2))
        descLabel.textColor     = UIColor.whiteColor()
        descLabel.textAlignment = NSTextAlignment.Left
        descLabel.numberOfLines = 6
        descLabel.lineBreakMode = NSLineBreakMode.ByWordWrapping
        descLabel.text          = desc

        let page                = EAIntroPage()
        page.title              = title
        page.titlePositionY     = frame.height * 0.35
        page.bgColor            = bgColor
        page.titleIconView      = UIImageView(image: UIImage(named: imageName))
        page.subviews           = [descLabel]

        if deviceType == DeviceType.iPhone4OrLess || deviceType == DeviceType.iPhone5 {
            descLabel.font      = UIFont.systemFontOfSize(14)
            page.titleFont      = UIFont.boldSystemFontOfSize(20)
        } else {
            descLabel.font      = UIFont.systemFontOfSize(16)
            page.titleFont      = UIFont.boldSystemFontOfSize(24)
        }

        return page
    }

    class func lastPage(frame: CGRect, delegate: TutorialViewDelegate?) -> EAIntroPage {
        let height = frame.height
        let width  = frame.width
        let loginButton         = UIButton(frame: CGRect(x: 0, y: height*0.48,
            width: width, height: height*0.2))
        loginButton.contentMode = UIViewContentMode.ScaleAspectFit
        loginButton.setImage(UIImage(named: "feedly"), forState: UIControlState.Normal)
        if let _delegate = delegate {
            loginButton.addTarget(_delegate, action: "tutorialLoginButtonTapped",
                forControlEvents: UIControlEvents.TouchUpInside)
        }
        let page            = EAIntroPage()
        page.title          = String.tutorialString("last_page_title")
        page.titleFont      = UIFont.boldSystemFontOfSize(32)
        page.titlePositionY = height * 0.6
        page.titleIconView  = UIImageView(image: UIImage(named: "note"))
        page.desc           = String.tutorialString("last_page_desc")
        page.descFont       = UIFont.systemFontOfSize(20)
        page.descPositionY  = height * 0.3
        page.bgColor        = UIColor.theme
        page.subviews       = [loginButton]
        return page
    }
}