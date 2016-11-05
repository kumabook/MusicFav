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
    class func tutorialView(_ frame: CGRect, delegate: TutorialViewDelegate?) -> TutorialView {
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
        let pages: [EAIntroPage] = [firstPage(frame),
                                    streamPage,
                                    playlistPage,
                                    playerPage,
                                    menuPage,
            lastPage(frame, delegate: delegate)]
        let tutorialView = TutorialView(frame: frame, andPages: pages)
        tutorialView?.delegate = delegate
        return tutorialView!
    }

    class func firstPage(_ frame: CGRect) -> EAIntroPage {
        let height = frame.height
        let width  = frame.width
        let page = EAIntroPage()
        page.title            = String.tutorialString("first_page_title")
        page.titlePositionY   = frame.height * 0.55
        let imageView         = UIImageView(image: UIImage(named: "note"))
        imageView.contentMode = UIViewContentMode.scaleAspectFit
        imageView.frame       = CGRect(x: 0, y: 0, width: width * 0.3, height: height * 0.3)
        page.titleIconView    = imageView
        page.desc             = String.tutorialString("first_page_desc")
        page.descPositionY    = frame.height * 0.4
        page.bgColor          = UIColor.theme
        let deviceType = DeviceType.from(UIDevice.current)
        switch deviceType {
        case .iPhone4OrLess:
            page.descFont     = UIFont.systemFont(ofSize: 14)
            page.titleFont    = UIFont.boldSystemFont(ofSize: 20)
        case .iPhone5:
            page.descFont     = UIFont.systemFont(ofSize: 16)
            page.titleFont    = UIFont.boldSystemFont(ofSize: 24)
        case .iPhone6:
            page.descFont     = UIFont.systemFont(ofSize: 18)
            page.titleFont    = UIFont.boldSystemFont(ofSize: 26)
        case .iPhone6Plus:
            page.descFont     = UIFont.systemFont(ofSize: 20)
            page.titleFont    = UIFont.boldSystemFont(ofSize: 28)
        case .iPad:
            page.descFont     = UIFont.systemFont(ofSize: 30)
            page.titleFont    = UIFont.boldSystemFont(ofSize: 36)
        case .unknown:
            page.descFont     = UIFont.systemFont(ofSize: 16)
            page.titleFont    = UIFont.boldSystemFont(ofSize: 24)
        }
        return page
    }

    class func capturePage(_ frame: CGRect, title: String, desc: String, bgColor: UIColor, imageName: String) -> EAIntroPage {
        let height = frame.height
        let width  = frame.width
        let deviceType = DeviceType.from(UIDevice.current)
        let descLabel           = UILabel(frame: CGRect(x: width*0.1, y: height*0.58,
            width: width*0.8, height: height*0.2))
        descLabel.textColor     = UIColor.white
        descLabel.textAlignment = NSTextAlignment.left
        descLabel.numberOfLines = 6
        descLabel.lineBreakMode = NSLineBreakMode.byWordWrapping
        descLabel.text          = desc

        let page                = EAIntroPage()
        page.title              = title
        page.titlePositionY     = frame.height * 0.5
        page.bgColor            = bgColor
        let imageView           = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode   = UIViewContentMode.scaleAspectFit
        imageView.frame         = CGRect(x: 0, y: 0, width: width * 0.8, height: height * 0.4)
        page.titleIconView      = imageView
        page.subviews           = [descLabel]

        switch deviceType {
        case .iPhone4OrLess:
            descLabel.font      = UIFont.systemFont(ofSize: 12)
            page.titleFont      = UIFont.boldSystemFont(ofSize: 16)
        case .iPhone5:
            descLabel.font      = UIFont.systemFont(ofSize: 14)
            page.titleFont      = UIFont.boldSystemFont(ofSize: 20)
        case .iPhone6:
            descLabel.font      = UIFont.systemFont(ofSize: 16)
            page.titleFont      = UIFont.boldSystemFont(ofSize: 24)
        case .iPhone6Plus:
            descLabel.font      = UIFont.systemFont(ofSize: 18)
            page.titleFont      = UIFont.boldSystemFont(ofSize: 26)
        case .iPad:
            descLabel.font      = UIFont.systemFont(ofSize: 26)
            page.titleFont      = UIFont.boldSystemFont(ofSize: 36)
        case .unknown:
            descLabel.font      = UIFont.systemFont(ofSize: 18)
            page.titleFont      = UIFont.boldSystemFont(ofSize: 26)
        }
        return page
    }

    class func lastPage(_ frame: CGRect, delegate: TutorialViewDelegate?) -> EAIntroPage {
        let height = frame.height
        let width  = frame.width
        let deviceType = DeviceType.from(UIDevice.current)
        let page              = EAIntroPage()
        page.title            = String.tutorialString("last_page_title")
        page.titleFont        = UIFont.boldSystemFont(ofSize: 32)
        page.titlePositionY   = height * 0.5
        let imageView         = UIImageView(image: UIImage(named: "note"))
        imageView.contentMode = UIViewContentMode.scaleAspectFit
        imageView.frame       = CGRect(x: 0, y: 0, width: width * 0.4, height: height * 0.4)
        page.titleIconView    = imageView
        page.desc             = String.tutorialString("last_page_desc")
        page.descFont         = UIFont.systemFont(ofSize: 20)
        page.descPositionY    = height * 0.4
        page.bgColor          = UIColor.theme
        switch deviceType {
        case .iPhone4OrLess:
            page.descFont     = UIFont.systemFont(ofSize: 16)
            page.titleFont    = UIFont.boldSystemFont(ofSize: 24)
        case .iPhone5:
            page.descFont     = UIFont.systemFont(ofSize: 18)
            page.titleFont    = UIFont.boldSystemFont(ofSize: 26)
        case .iPhone6:
            page.descFont     = UIFont.systemFont(ofSize: 22)
            page.titleFont    = UIFont.boldSystemFont(ofSize: 28)
        case .iPhone6Plus:
            page.descFont     = UIFont.systemFont(ofSize: 24)
            page.titleFont    = UIFont.boldSystemFont(ofSize: 30)
        case .iPad:
            page.descFont     = UIFont.systemFont(ofSize: 30)
            page.titleFont    = UIFont.boldSystemFont(ofSize: 36)
        case .unknown:
            page.descFont     = UIFont.systemFont(ofSize: 18)
            page.titleFont    = UIFont.boldSystemFont(ofSize: 26)
        }
        return page
    }
}
