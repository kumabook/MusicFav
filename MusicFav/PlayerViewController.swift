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
        case portrait
        case landscapeLeft
        case portraitUpsideDown
        case landscapeRight

        var isPortrait: Bool { return self == .portrait || self == .portraitUpsideDown }

        var angle: CGFloat {
            switch self {
            case .portrait:           return 0
            case .landscapeLeft:      return CGFloat(Double.pi / 2)
            case .portraitUpsideDown: return CGFloat(Double.pi)
            case .landscapeRight:     return CGFloat(Double.pi / 2 * 3)
            }
        }

        var rotateRight: VideoOrientation {
            switch self {
            case .portrait:           return .landscapeLeft
            case .landscapeLeft:      return .portraitUpsideDown
            case .portraitUpsideDown: return .landscapeRight
            case .landscapeRight:     return .portrait
            }
        }

        func transfrom(_ view: UIView) -> CGAffineTransform {
            let s = view.frame.height / view.frame.width
            let t = CGAffineTransform(rotationAngle: self.angle)
            switch self {
            case .portrait:           return t.scaledBy(x: 1, y: 1)
            case .landscapeLeft:      return t.scaledBy(x: s, y: s)
            case .portraitUpsideDown: return t.scaledBy(x: 1, y: 1)
            case .landscapeRight:     return t.scaledBy(x: s, y: s)
            }
        }
    }
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let buttonSize:    CGFloat = 40.0
    let buttonPadding: CGFloat = 20.0

    var likeButton:     UIButton!
    var providerButton: UIButton!
    var rotateButton:   UIButton!

    var videoViewOriginalCenter: CGPoint!
    var videoOrientation: VideoOrientation!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func initializeSubviews() {
        super.initializeSubviews()
        likeButton = UIButton(type: UIButtonType.system)
        likeButton.tintColor = UIColor.white
        likeButton.setImage(UIImage(named: "like"), for: UIControlState())
        likeButton.addTarget(self, action: #selector(PlayerViewController.likeButtonTapped), for: .touchUpInside)
        view.addSubview(likeButton)

        rotateButton = UIButton(type: UIButtonType.system)
        rotateButton.tintColor = UIColor.white
        rotateButton.setImage(UIImage(named: "rotate"), for: UIControlState())
        rotateButton.addTarget(self, action: #selector(PlayerViewController.rotateButtonTapped), for: .touchUpInside)
        view.addSubview(rotateButton)
        providerButton = UIButton(type: UIButtonType.custom)
        providerButton.addTarget(self, action: #selector(PlayerViewController.providerButtonTapped), for: .touchUpInside)
        providerButton.imageView?.contentMode = .scaleAspectFit
        view.addSubview(providerButton)
        videoViewOriginalCenter = videoView?.center
        videoOrientation = VideoOrientation.portrait
    }

    override func updateConstraints() {
        super.updateConstraints()
        likeButton.snp.makeConstraints { make in
            make.left.equalTo(self.view.snp.left).offset(self.buttonPadding)
            make.bottom.equalTo(self.view.snp.bottom).offset(-self.buttonPadding*1.5)
            make.width.equalTo(self.buttonSize)
            make.height.equalTo(self.buttonSize)
        }
        providerButton.snp.makeConstraints { make in
            make.right.equalTo(self.view.snp.right).offset(-self.buttonPadding)
            make.bottom.equalTo(self.view.snp.bottom).offset(-self.buttonPadding*1.5)
            make.width.equalTo(self.buttonSize)
            make.height.equalTo(self.buttonSize)
        }
        rotateButton.snp.makeConstraints { make in
            make.right.equalTo(self.view.snp.right).offset(-self.buttonPadding*2 - self.buttonSize)
            make.bottom.equalTo(self.view.snp.bottom).offset(-self.buttonPadding*1.5)
            make.width.equalTo(self.buttonSize)
            make.height.equalTo(self.buttonSize)
        }
    }

    @objc func likeButtonTapped() {
        let app = UIApplication.shared.delegate as! AppDelegate
        guard let track = app.player?.currentTrack as? MusicFeeder.Track else { return }
        showSelectPlaylistViewController([track])
    }

    @objc func rotateButtonTapped() {
        videoOrientation = videoOrientation.rotateRight
        let isPortrait = self.videoOrientation.isPortrait
        let views = [closeButton, likeButton, slider, titleLabel, subTitleLabel, currentLabel, totalLabel] as [UIView]
        UIView.animate(withDuration: 0.5, animations: {
            if isPortrait {
                self.videoView?.center = self.videoViewOriginalCenter
            } else {
                self.videoView?.center = CGPoint(x: self.videoViewOriginalCenter.x, y: self.view.center.y)
            }
            self.videoView?.transform = self.videoOrientation.transfrom(self.view)
            views.forEach { $0.isHidden = !isPortrait }
        }) 
    }

    @objc func providerButtonTapped() {
        let app = UIApplication.shared.delegate as! AppDelegate
        guard let track = app.player?.currentTrack as? MusicFeeder.Track else { return }
        track.open()
    }

    override func updateViewWithTrack(_ track: PlayerKit.Track, animated: Bool) {
        super.updateViewWithTrack(track, animated: animated)
        rotateButton.isHidden = !track.isVideo
        if let track = track as? MusicFeeder.Track {
            providerButton.setImage(UIImage(named: track.provider.iconImageName), for: UIControlState.normal)
        }
    }

    func showSelectPlaylistViewController(_ tracks: [MusicFeeder.Track]) {
        let ptc = SelectPlaylistTableViewController()
        ptc.callback = {(playlist: MusicFeeder.Playlist?) in
            if let p = playlist {
                switch p.appendTracks(tracks) {
                case .success:
                    break
                case .failure:
                    let message = "Failed to add tracks".localize()
                    let _ = UIAlertController.show(self, title: "MusicFav", message: message, handler: { action in })
                case .exceedLimit:
                    let message = String(format: "Track number of per playlist is limited to %d.".localize(), Playlist.trackNumberLimit) +
                        "Do you want to purchase \"Unlock Everything\".".localize()
                    let _ = UIAlertController.showPurchaseAlert(self, title: "MusicFav", message: message, handler: {action in })
                }
            }
            ptc.callback = nil
        }
        let nvc = UINavigationController(rootViewController: ptc)
        appDelegate.window?.rootViewController?.present(nvc, animated: true, completion: nil)
    }
}
