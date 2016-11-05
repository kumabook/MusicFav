//
//  TimelineTableViewCell.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/27/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveSwift
import MusicFeeder
import MCSwipeTableViewCell

protocol TimelineTableViewCellDelegate: class {
    func trackSelected(_ sender: TimelineTableViewCell, index: Int, track: Track, playlist: Playlist)
    func trackScrollViewMarginTouched(_ sender: TimelineTableViewCell, playlist: Playlist?)
    func playButtonTouched(_ sender: TimelineTableViewCell)
    func articleButtonTouched(_ sender: TimelineTableViewCell)
}

class TimelineTableViewCell: MCSwipeTableViewCell {
    let thumbnailWidth: CGFloat = 80.0
    let iconWidth:      CGFloat = 32.0
    let margin:         CGFloat = 7.0
    let padding:        CGFloat = 12.0

    let swipeCellPadding:       CGFloat   = 5.0
    let swipeCellLabelFontSize: CGFloat   = 20.0
    var swipeCellBackgroundColor = UIColor(red: 227/255, green: 227/255, blue: 227/255, alpha: 1.0)

    @IBOutlet weak var titleLabel:          UILabel!
    @IBOutlet weak var descriptionLabel:    UILabel!
    @IBOutlet weak var dateLabel:           UILabel!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var playButton:          UIButton!
    @IBOutlet weak var articleButton:       UIButton!
    @IBOutlet weak var trackNumLabel:       UILabel!
    @IBOutlet weak var thumbListContainer:  UIScrollView!

    weak var timelineDelegate: TimelineTableViewCellDelegate?

    var indicator:   OnpuIndicatorView!
    var playerState: PlayerState!
    var observer: Disposable?
    var playlist: Playlist?
    var imageViews: [UIImageView] = []

    override func awakeFromNib() {
        super.awakeFromNib()
        indicator = OnpuIndicatorView(frame: CGRect(x: 0,
                                                    y: 0,
                                                width: iconWidth,
                                               height: iconWidth))
        indicator.isHidden           = true
        thumbListContainer.addSubview(indicator)
        indicator.isUserInteractionEnabled = true
        playButton.addTarget(self, action: #selector(TimelineTableViewCell.playButtonTouched), for: UIControlEvents.touchUpInside)
        articleButton.addTarget(self, action: #selector(TimelineTableViewCell.articleButtonTouched), for: UIControlEvents.touchUpInside)
        selectionStyle = UITableViewCellSelectionStyle.none
        playerState = PlayerState.init
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
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

    func loadThumbnail(_ imageView: UIImageView, track: Track) {
        if let thumbnailUrl = track.thumbnailUrl {
            imageView.sd_setImage(with: thumbnailUrl, placeholderImage: UIImage(named: "default_thumb"))
        } else {
            imageView.image = UIImage(named: "default_thumb")
        }
    }

    func loadThumbnails(_ playlist: Playlist) {
        let tw = thumbnailWidth
        clearThumbnails()
        self.playlist = playlist
        for (i, track) in playlist.getTracks().enumerated() {
            let rect = CGRect(x: margin + (tw + padding) * CGFloat(i),
                              y: margin,
                          width: tw,
                         height: tw)
            let imageView = UIImageView(frame: rect)
            imageView.isUserInteractionEnabled = true
            imageView.addGestureRecognizer(UITapGestureRecognizer(target:self, action:#selector(TimelineTableViewCell.thumbImageTapped(_:))))
            imageViews.append(imageView)
            thumbListContainer.addSubview(imageView)
            loadThumbnail(imageView, track: track)
        }
        let count        = CGFloat(playlist.tracks.count)
        let widthPerPage = thumbListContainer.frame.width
        let pageNum      = Int((thumbnailWidth + padding) * count / widthPerPage) + 1
        let contentWidth = widthPerPage * CGFloat(pageNum)
        let marginView   = UIView(frame: CGRect(x: count * tw, y: 0.0, width: contentWidth - count * tw, height: tw))
        marginView.addGestureRecognizer(UITapGestureRecognizer(target:self, action:#selector(TimelineTableViewCell.trackScrollViewMarginTouched(_:))))
        thumbListContainer.addSubview(marginView)
        thumbListContainer.contentSize = CGSize(width: contentWidth, height: thumbnailWidth)
    }

    func updatePlayerIcon(_ index: Int, playerState: PlayerState) {
        let tw = thumbnailWidth
        let htw = thumbnailWidth * 0.5
        indicator.center = CGPoint(x: margin + (tw + padding) * CGFloat(index) + htw, y: htw + margin)
        thumbListContainer.bringSubview(toFront: indicator)
        self.playerState = playerState
        switch playerState {
        case .init:
            indicator.isHidden = true
            indicator.stopAnimating()
            indicator.setColor(.blue)
        case .load:
            indicator.isHidden = false
            indicator.startAnimating(.colorSwitch)
        case .loadToPlay:
            indicator.isHidden = false
            indicator.startAnimating(.colorSwitch)
        case .play:
            indicator.isHidden = false
            indicator.startAnimating(.rotate)
        case .pause:
            indicator.isHidden = false
            indicator.stopAnimating()
            indicator.setColor(.blue)
        }
    }

    func thumbImageTapped(_ sender: UITapGestureRecognizer) {
        if let playlist = self.playlist {
            if let d = timelineDelegate {
                if let view = sender.view as? UIImageView {
                    if let i = imageViews.index(of: view) {
                        d.trackSelected(self, index: i, track: playlist.getTracks()[i], playlist: playlist)
                    }
                }
            }
        }
    }

    func trackScrollViewMarginTouched(_ sender: UITapGestureRecognizer) {
        timelineDelegate?.trackScrollViewMarginTouched(self, playlist: self.playlist)
    }

    func playButtonTouched() {
        timelineDelegate?.playButtonTouched(self)
    }

    func articleButtonTouched() {
        timelineDelegate?.articleButtonTouched(self)
    }

    func observePlaylist(_ playlist: Playlist) {
        observer?.dispose()
        observer = playlist.signal.observeResult({ result in
            guard let event = result.value else { return }
            UIScheduler().schedule {
                switch event {
                case .load(let index):
                    self.loadThumbnail(self.imageViews[index], track: playlist.getTracks()[index])
                case .changePlayState(let index, let playerState):
                    self.updatePlayerIcon(index, playerState: playerState)
                }
            }
            return
        })
    }

    func buildImageView(markAs: EntryRepository.RemoveMark) -> UIView {
        let view              = UIView()
        let label             = UILabel()
        let imageView         = UIImageView(image: UIImage(named: "checkmark"))
        label.text            = cellText(markAs)
        label.textColor       = UIColor.white
        label.font            = UIFont.boldSystemFont(ofSize: swipeCellLabelFontSize)
        imageView.contentMode = UIViewContentMode.center

        view.addSubview(label)
        view.addSubview(imageView)
        
        label.snp.makeConstraints { make in
            make.right.equalTo(imageView.snp.left).offset(-self.padding)
            make.centerY.equalTo(view.snp.centerY)
        }
        imageView.snp.makeConstraints { make in
            make.centerX.equalTo(view.snp.centerX)
            make.centerY.equalTo(view.snp.centerY)
        }
        return view
    }

    func cellText(_ markAs: EntryRepository.RemoveMark) -> String {
        switch markAs {
        case .read:   return "Mark as Read".localize()
        case .unread: return "Mark as Unread".localize()
        case .unsave: return "Mark as Unsaved".localize()
        }
    }

    var markAsReadImageView:    UIView  { return buildImageView(markAs: .read) }
    var markAsUnreadImageView:  UIView  { return buildImageView(markAs: .unread) }
    var markAsUnsavedImageView: UIView  { return buildImageView(markAs: .unsave) }
    var markAsReadColor:        UIColor { return UIColor.red }
    var markAsUnreadColor:      UIColor { return UIColor.green }
    var markAsUnsavedColor:     UIColor { return UIColor.blue }

    func prepareSwipeViews(_ markAs: EntryRepository.RemoveMark, onSwipe: @escaping (MCSwipeTableViewCell) -> Void) {
        if responds(to: #selector(setter: UITableViewCell.separatorInset)) {
            separatorInset = UIEdgeInsets.zero
        }
        contentView.backgroundColor = UIColor.white
        defaultColor   = swipeCellBackgroundColor
        switch markAs {
        case .read:
            setSwipeGestureWith(markAsReadImageView,
                color: markAsReadColor,
                mode: .switch,
                state: .state1) { (cell, state, mode) in }
            setSwipeGestureWith(markAsReadImageView,
                color: markAsReadColor,
                mode: MCSwipeTableViewCellMode.exit,
                state: MCSwipeTableViewCellState.state2) { (cell, state, mode) in
                    onSwipe(cell!)
            }
        case .unread:
            setSwipeGestureWith(markAsUnreadImageView,
                color: markAsUnreadColor,
                mode: .switch,
                state: .state1) { (cell, state, mode) in }
            setSwipeGestureWith(markAsUnreadImageView,
                color: markAsUnreadColor,
                mode: MCSwipeTableViewCellMode.exit,
                state: MCSwipeTableViewCellState.state2) { (cell, state, mode) in
                    onSwipe(cell!)
            }
        case .unsave:
            setSwipeGestureWith(markAsUnsavedImageView,
                color: markAsUnsavedColor,
                mode: .switch,
                state: .state1) { (cell, state, mode) in }
            setSwipeGestureWith(markAsUnsavedImageView,
                color: markAsUnsavedColor,
                mode: MCSwipeTableViewCellMode.exit,
                state: MCSwipeTableViewCellState.state2) { (cell, state, mode) in
                    onSwipe(cell!)
            }
        }
    }

}
