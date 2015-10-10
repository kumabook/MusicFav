//
//  TimelineTableViewCell.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/27/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import MusicFeeder

protocol TimelineTableViewCellDelegate: class {
    func trackSelected(sender: TimelineTableViewCell, index: Int, track: Track, playlist: Playlist)
    func trackScrollViewMarginTouched(sender: TimelineTableViewCell, playlist: Playlist?)
    func playButtonTouched(sender: TimelineTableViewCell)
    func articleButtonTouched(sender: TimelineTableViewCell)
}

class TimelineTableViewCell: UITableViewCell {
    let thumbnailWidth: CGFloat = 80.0
    let iconWidth:      CGFloat = 32.0
    let margin:         CGFloat = 7.0
    let padding:        CGFloat = 12.0

    @IBOutlet weak var titleLabel:          UILabel!
    @IBOutlet weak var descriptionLabel:    UILabel!
    @IBOutlet weak var dateLabel:           UILabel!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var playButton:          UIButton!
    @IBOutlet weak var articleButton:       UIButton!
    @IBOutlet weak var trackNumLabel:       UILabel!
    @IBOutlet weak var thumbListContainer:  UIScrollView!

    weak var delegate: TimelineTableViewCellDelegate?

    var playerIcon:  UIImageView!
    var indicator:   UIActivityIndicatorView!
    var playerState: PlayerState!
    var observer: Disposable?
    var playlist: Playlist?
    var imageViews: [UIImageView] = []

    override func awakeFromNib() {
        super.awakeFromNib()
        playerIcon = UIImageView(frame: CGRect(x: 0,
                                               y: 0,
                                           width: iconWidth,
                                          height: iconWidth))
        playerIcon.hidden = true
        indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
        indicator.hidesWhenStopped = true
        indicator.hidden           = true
        thumbListContainer.addSubview(playerIcon)
        thumbListContainer.addSubview(indicator)
        playButton.addTarget(self, action: "playButtonTouched", forControlEvents: UIControlEvents.TouchUpInside)
        articleButton.addTarget(self, action: "articleButtonTouched", forControlEvents: UIControlEvents.TouchUpInside)
        selectionStyle = UITableViewCellSelectionStyle.None
        playerState = .Init
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
        for (i, track) in playlist.getTracks().enumerate() {
            let rect = CGRect(x: margin + (tw + padding) * CGFloat(i),
                              y: margin,
                          width: tw,
                         height: tw)
            let imageView = UIImageView(frame: rect)
            imageView.userInteractionEnabled = true
            imageView.addGestureRecognizer(UITapGestureRecognizer(target:self, action:"thumbImageTapped:"))
            imageViews.append(imageView)
            thumbListContainer.addSubview(imageView)
            loadThumbnail(imageView, track: track)
        }
        let count        = CGFloat(playlist.tracks.count)
        let widthPerPage = thumbListContainer.frame.width
        let pageNum      = Int((thumbnailWidth + padding) * count / widthPerPage) + 1
        let contentWidth = widthPerPage * CGFloat(pageNum)
        let marginView   = UIView(frame: CGRect(x: count * tw, y: 0.0, width: contentWidth - count * tw, height: tw))
        marginView.addGestureRecognizer(UITapGestureRecognizer(target:self, action:"trackScrollViewMarginTouched:"))
        thumbListContainer.addSubview(marginView)
        thumbListContainer.contentSize = CGSize(width: contentWidth, height: thumbnailWidth)
    }

    func updatePlayerIcon(index: Int, playerState: PlayerState) {
        let startTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC)))
        dispatch_after(startTime, dispatch_get_main_queue()) {
            self._updatePlayerIcon(index, playerState: playerState)
        }
    }

    func _updatePlayerIcon(index: Int, playerState: PlayerState) {
        let tw = thumbnailWidth
        let htw = thumbnailWidth * 0.5
        playerIcon.center = CGPoint(x: margin + (tw + padding) * CGFloat(index) + htw, y: htw + margin)
        indicator.center = CGPoint(x: margin + (tw + padding) * CGFloat(index) + htw, y: htw + margin)
        thumbListContainer.bringSubviewToFront(playerIcon)
        thumbListContainer.bringSubviewToFront(indicator)
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

    func startPlayerIconAnimation() {
        playerIcon.image              = UIImage(named: "loading_icon")
        let rotationAnimation         = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.toValue     = NSNumber(float: Float(2.0 * M_PI))
        rotationAnimation.duration    = 1.0
        rotationAnimation.cumulative  = true
        rotationAnimation.repeatCount = Float.infinity
        playerIcon.layer.removeAllAnimations()
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
                    if let i = imageViews.indexOf(view) {
                        delegate.trackSelected(self, index: i, track: playlist.getTracks()[i], playlist: playlist)
                    }
                }
            }
        }
    }

    func trackScrollViewMarginTouched(sender: UITapGestureRecognizer) {
        delegate?.trackScrollViewMarginTouched(self, playlist: self.playlist)
    }

    func playButtonTouched() {
        delegate?.playButtonTouched(self)
    }

    func articleButtonTouched() {
        delegate?.articleButtonTouched(self)
    }

    func observePlaylist(playlist: Playlist) {
        observer?.dispose()
        observer = playlist.signal.observeNext({ event in
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
