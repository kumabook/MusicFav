//
//  PlaylistStreamTableViewCell.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/5/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import Snap
import ReactiveCocoa
import MusicFeeder

protocol PlaylistStreamTableViewCellDelegate: class {
    func trackSelectedAt(index: Int, track: Track, playlist: Playlist)
    func trackScrollViewMarginTapped(playlist: Playlist?)
}

class PlaylistStreamTableViewCell: UITableViewCell {
    let thumbnailWidth: CGFloat = 54.0

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var trackThumbScrollView: UIScrollView!

    weak var delegate: PlaylistStreamTableViewCellDelegate?

    var imageViews:  [UIImageView] = []
    var playerIcon:  UIImageView!
    var indicator:   UIActivityIndicatorView!
    var playlist:    Playlist?
    var observer:    Disposable?
    var playerState: PlayerState!

    @IBOutlet weak var trackNumLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        let tw = thumbnailWidth
        playerIcon = UIImageView(frame: CGRect(x: 0, y: 0, width: tw*0.6, height: tw*0.6))
        playerIcon.hidden = true
        indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
        indicator.hidesWhenStopped = true
        indicator.hidden           = true
        trackThumbScrollView.addSubview(playerIcon)
        trackThumbScrollView.addSubview(indicator)
        playerState = .Init
    }

    deinit {
        observer?.dispose()
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func clearThumbnails() {
        observer?.dispose()
        observer = nil
        for imageView in imageViews {
            imageView.sd_cancelCurrentImageLoad()
            imageView.removeFromSuperview()
        }
        imageViews = []
    }

    func loadThumbnail(imageView: UIImageView, track: Track) {
        if let thumbnailUrl = track.thumbnailUrl {
            imageView.sd_setImageWithURL(thumbnailUrl,
                placeholderImage: UIImage(named: "default_thumb"),
                completed: { (image, error, cactypeType, url) -> Void in
            })
        } else {
            imageView.image = UIImage(named: "default_thumb")
        }
    }

    func loadThumbnails(playlist: Playlist) {
        let tw = thumbnailWidth
        clearThumbnails()
        self.playlist = playlist
        for (i, track) in enumerate(playlist.getTracks()) {
            let rect = CGRect(x: tw * CGFloat(i), y: 0.0, width: tw, height: tw)
            let imageView = UIImageView(frame: rect)
            imageView.userInteractionEnabled = true
            imageView.addGestureRecognizer(UITapGestureRecognizer(target:self, action:"thumbImageTapped:"))
            imageViews.append(imageView)
            trackThumbScrollView.addSubview(imageView)
            loadThumbnail(imageView, track: track)
        }
        let count        = CGFloat(playlist.tracks.count)
        let widthPerPage = trackThumbScrollView.frame.width
        let pageNum      = Int(thumbnailWidth * count / widthPerPage) + 1
        let contentWidth = widthPerPage * CGFloat(pageNum)
        let marginView   = UIView(frame: CGRect(x: count * tw, y: 0.0, width: contentWidth - count * tw, height: tw))
        marginView.addGestureRecognizer(UITapGestureRecognizer(target:self, action:"trackScrollViewMarginTapped:"))
        trackThumbScrollView.addSubview(marginView)
        trackThumbScrollView.contentSize = CGSize(width: contentWidth, height: thumbnailWidth)
    }
    func updatePlayerIcon(index: Int, playerState: PlayerState) {
        let startTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC)))
        dispatch_after(startTime, dispatch_get_main_queue()) {
            self._updatePlayerIcon(index, playerState: playerState)
        }
    }

    func _updatePlayerIcon(index: Int, playerState: PlayerState) {
        let tw = thumbnailWidth
        let htw = tw * 0.5
        playerIcon.center = CGPoint(x: tw * CGFloat(index) + htw, y: htw)
        indicator.center = CGPoint(x: tw * CGFloat(index) + htw, y: htw)
        trackThumbScrollView.bringSubviewToFront(playerIcon)
        trackThumbScrollView.bringSubviewToFront(indicator)
        if self.playerState != playerState {
            self.playerState = playerState
            switch playerState {
            case .Init:
                playerIcon.hidden = true
                indicator.stopAnimating()
            case .Load:
                playerIcon.hidden = true
                indicator.hidden = false
                indicator.startAnimating()
            case .LoadToPlay:
                playerIcon.hidden = true
                indicator.hidden = false
                indicator.startAnimating()
            case .Play:
                playerIcon.hidden = false
                startPlayerIconAnimation()
                indicator.stopAnimating()
            case .Pause:
                playerIcon.hidden = false
                stopPlayerIconAnimation()
                indicator.stopAnimating()
            }
        }
    }

    func startPlayerIconAnimation() {
        playerIcon.image              = UIImage(named: "loading_icon")
        let rotationAnimation         = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.toValue     = NSNumber(float: Float(2.0 * M_PI))
        rotationAnimation.duration    = 1.0
        rotationAnimation.cumulative  = true
        rotationAnimation.repeatCount = Float.infinity
        playerIcon.layer.addAnimation(rotationAnimation, forKey: "rotationAnimation")
    }

    func stopPlayerIconAnimation() {
        playerIcon.layer.removeAllAnimations()
        playerIcon.image = UIImage(named: "loading_icon_1")
    }

    func thumbImageTapped(sender: UITapGestureRecognizer) {
        if let playlist = self.playlist {
            if let delegate = self.delegate {
                if let view = sender.view as? UIImageView {
                    if let i = find(imageViews, view) {
                        delegate.trackSelectedAt(i, track: playlist.getTracks()[i], playlist: playlist)
                    }
                }
            }
        }
    }

    func trackScrollViewMarginTapped(sender: UITapGestureRecognizer) {
        delegate?.trackScrollViewMarginTapped(self.playlist)
    }

    func observePlaylist(playlist: Playlist) {
        observer?.dispose()
        observer = playlist.signal.observe(next: { event in
            UIScheduler().schedule {
                switch event {
                case .Load(let index):
                    self.loadThumbnail(self.imageViews[index], track: playlist.getTracks()[index])
                case .ChangePlayState(let index, let playerState):
                    self.updatePlayerIcon(index, playerState: playerState)
                }
            }
            return
        })
    }
}
