//
//  PlayerViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/12/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import PlayerKit
import MusicFeeder

class PlayerViewController: PlayerKit.SimplePlayerViewController {
    enum VideoOrientation {
        case Portrait
        case LandscapeLeft
        case PortraitUpsideDown
        case LandscapeRight

        var isPortrait: Bool { return self == .Portrait || self == .PortraitUpsideDown }

        var angle: CGFloat {
            switch self {
            case .Portrait:           return 0
            case .LandscapeLeft:      return CGFloat(M_PI_2)
            case .PortraitUpsideDown: return CGFloat(M_PI)
            case .LandscapeRight:     return CGFloat(M_PI_2 * 3)
            }
        }

        var rotateRight: VideoOrientation {
            switch self {
            case .Portrait:           return .LandscapeLeft
            case .LandscapeLeft:      return .PortraitUpsideDown
            case .PortraitUpsideDown: return .LandscapeRight
            case .LandscapeRight:     return .Portrait
            }
        }

        func transfrom(view: UIView) -> CGAffineTransform {
            let s = view.frame.height / view.frame.width
            let t = CGAffineTransformMakeRotation(self.angle)
            switch self {
            case .Portrait:           return CGAffineTransformScale(t, 1, 1)
            case .LandscapeLeft:      return CGAffineTransformScale(t, s, s)
            case .PortraitUpsideDown: return CGAffineTransformScale(t, 1, 1)
            case .LandscapeRight:     return CGAffineTransformScale(t, s, s)
            }
        }
    }
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    let buttonSize:    CGFloat = 40.0
    let buttonPadding: CGFloat = 20.0
    var likeButton:   UIButton!
    var rotateButton: UIButton!

    var videoViewOriginalCenter: CGPoint!
    var videoOrientation: VideoOrientation!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func initializeSubviews() {
        super.initializeSubviews()
        likeButton = UIButton(type: UIButtonType.System)
        likeButton.tintColor = UIColor.whiteColor()
        likeButton.setImage(UIImage(named: "like"), forState: UIControlState())
        likeButton.addTarget(self, action: #selector(PlayerViewController.likeButtonTapped), forControlEvents: UIControlEvents.TouchUpInside)
        view.addSubview(likeButton)

        rotateButton = UIButton(type: UIButtonType.System)
        rotateButton.tintColor = UIColor.whiteColor()
        rotateButton.setImage(UIImage(named: "rotate"), forState: UIControlState())
        rotateButton.addTarget(self, action: #selector(PlayerViewController.rotateButtonTapped), forControlEvents: UIControlEvents.TouchUpInside)
        view.addSubview(rotateButton)
        videoViewOriginalCenter = videoView.center
        videoOrientation = VideoOrientation.Portrait
    }

    override func updateConstraints() {
        super.updateConstraints()
        likeButton.snp_makeConstraints { make in
            make.left.equalTo(self.view.snp_left).offset(self.buttonPadding)
            make.bottom.equalTo(self.view.snp_bottom).offset(-self.buttonPadding*1.5)
            make.width.equalTo(self.buttonSize)
            make.height.equalTo(self.buttonSize)
        }
        rotateButton.snp_makeConstraints { make in
            make.right.equalTo(self.view.snp_right).offset(-self.buttonPadding)
            make.bottom.equalTo(self.view.snp_bottom).offset(-self.buttonPadding*1.5)
            make.width.equalTo(self.buttonSize)
            make.height.equalTo(self.buttonSize)
        }
    }

    func likeButtonTapped() {
        let app = UIApplication.sharedApplication().delegate as! AppDelegate
        if let track = app.player?.currentTrack as? MusicFeeder.Track{
            showSelectPlaylistViewController([track])
        }
    }

    func rotateButtonTapped() {
        videoOrientation = videoOrientation.rotateRight
        let isPortrait = self.videoOrientation.isPortrait
        let views = [closeButton, likeButton, slider, titleLabel, subTitleLabel, currentLabel, totalLabel]
        UIView.animateWithDuration(0.5) {
            if isPortrait {
                self.videoView.center = self.videoViewOriginalCenter
            } else {
                self.videoView.center = CGPoint(x: self.videoViewOriginalCenter.x, y: self.view.center.y)
            }
            self.videoView.transform = self.videoOrientation.transfrom(self.view)
            views.forEach { $0.hidden = !isPortrait }
        }
    }

    override func updateViewWithTrack(track: PlayerKit.Track, animated: Bool) {
        super.updateViewWithTrack(track, animated: animated)
        rotateButton.hidden = !track.isVideo
    }

    func showSelectPlaylistViewController(tracks: [MusicFeeder.Track]) {
        let ptc = SelectPlaylistTableViewController()
        ptc.callback = {(playlist: MusicFeeder.Playlist?) in
            if let p = playlist {
                switch p.appendTracks(tracks) {
                case .Success:
                    break
                case .Failure:
                    let message = "Failed to add tracks".localize()
                    UIAlertController.show(self, title: "MusicFav", message: message, handler: { action in })
                case .ExceedLimit:
                    let message = String(format: "Track number of per playlist is limited to %d.".localize(), Playlist.trackNumberLimit) +
                        "Do you want to purchase \"Unlock Everything\".".localize()
                    UIAlertController.showPurchaseAlert(self, title: "MusicFav", message: message, handler: {action in })
                }
            }
            ptc.callback = nil
        }
        let nvc = UINavigationController(rootViewController: ptc)
        appDelegate.window?.rootViewController?.presentViewController(nvc, animated: true, completion: nil)
    }
}
