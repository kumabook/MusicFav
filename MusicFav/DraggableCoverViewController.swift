//
//  DraggableCoverViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 3/3/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import Snap

protocol DraggableCoverViewControllerDelegate {
    var containerView:   UIView { get }
    var thumbnailView:   UIView { get }
    var thumbnailWidth:  CGFloat { get }
    var thumbnailHeight: CGFloat { get }

    func setDraggableCoverView(parent: DraggableCoverViewController)
    func maximizeCoverView(parent: DraggableCoverViewController)
    func minimizeCoverView(parent: DraggableCoverViewController)
}

class DraggableCoverViewController: UIViewController {
    var coverViewController: DraggableCoverViewControllerDelegate!
    var floorViewController: UIViewController!

    var coverViewContainer: UIView!

    init(coverViewController:DraggableCoverViewControllerDelegate, floorViewController: UIViewController) {
        super.init()
        self.coverViewController = coverViewController
        self.floorViewController = floorViewController
        self.coverViewContainer  = UIView()
        self.coverViewController.setDraggableCoverView(self)
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func loadView() {
        super.loadView()
        view.addSubview(floorViewController.view)
        view.addSubview(coverViewContainer)
        coverViewController.containerView.backgroundColor = UIColor.blackColor()
        coverViewContainer.addSubview(coverViewController.containerView)
        floorViewController.view.frame = view.frame
        minimizeCoverView()
    }

    func minimizeCoverView() {
        coverViewContainer.clipsToBounds = true
        coverViewContainer.frame = CGRect(x: 0,
                                          y: view.frame.height - coverViewController.thumbnailHeight,
                                      width: coverViewController.thumbnailWidth,
                                     height: coverViewController.thumbnailHeight)
        coverViewController.minimizeCoverView(self)
    }

    func maximizeCoverView() {
        coverViewContainer.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
        coverViewController.maximizeCoverView(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        coverViewController.minimizeCoverView(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
