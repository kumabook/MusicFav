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

extension Provider {
    static let iconWidth:        CGFloat = 32.0
    static let youtubeIconWidth: CGFloat = 22.0
    static let iconHeight:       CGFloat = 16.0
    var iconImageName: String {
        switch self {
        case .youTube:
            return "youtube"
        case .soundCloud:
            return "soundcloud_icon"
        case .appleMusic:
            return "apple_music_icon"
        case .spotify:
            return "spotify_icon"
        default:
            return ""
        }
    }
    var iconImageSize: CGSize {
        switch self {
        case .youTube:
            return CGSize(width: Provider.youtubeIconWidth, height: Provider.iconHeight)
        case .soundCloud:
            return CGSize(width: Provider.iconWidth       , height: Provider.iconHeight)
        case .appleMusic:
            return CGSize(width: Provider.iconHeight      , height: Provider.iconHeight)
        case .spotify:
            return CGSize(width: Provider.iconHeight      , height: Provider.iconHeight)
        default:
            return CGSize(width: 0, height: 0)
        }
    }
}

enum TimelineTableViewCellItem {
    case track(Track)
    case album(Album)
    case playlist(ServicePlaylist)
    var provider: Provider {
        switch self {
        case .track(let track):       return track.provider
        case .album(let album):       return album.provider
        case .playlist(let playlist): return playlist.provider
        }
    }
    var thumbnailUrl: URL? {
        switch self {
        case .track(let track):       return track.thumbnailUrl
        case .album(let album):       return album.artworkUrl
        case .playlist(let playlist): return playlist.artworkUrl
        }
    }
    var iconImageName: String {
        switch self {
        case .track:    return "track"
        case .album:    return "album"
        case .playlist: return "playing_playlist"
        }
    }
}

protocol TimelineTableViewCellDelegate: class {
    func albumSelected(_  sender: TimelineTableViewCell, album: Album)
    func playlistSelected(_ sender: TimelineTableViewCell, playlist: ServicePlaylist)
    func trackSelected(_  sender: TimelineTableViewCell, index: Int, track: Track, playlist: Playlist)
    func scrollViewMarginTouched(_ sender: TimelineTableViewCell, playlist: Playlist?)
    func playButtonTouched(_ sender: TimelineTableViewCell)
    func articleButtonTouched(_ sender: TimelineTableViewCell)
}

class TimelineTableViewCell: MCSwipeTableViewCell {
    let thumbnailWidth:   CGFloat = 80.0
    let iconWidth:        CGFloat = 32.0
    let margin:           CGFloat = 7.0
    let padding:          CGFloat = 12.0

    let typeIconSize:       CGFloat = 32.0

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

    var indicator:    OnpuIndicatorView!
    var playerState:  PlayerState!
    var observer:     Disposable?
    var timelineItem: TimelineItem?
    var imageViews:   [UIImageView] = []
    var marginView: UIView?

    var playlist: Playlist? {
        guard let item = timelineItem else { return nil }
        switch item {
        case .entry(let entry):
            return entry.playlist
        default:
            return nil
        }
    }

    var playlistifiedEntry: PlaylistifiedEntry? {
        guard let item = timelineItem else { return nil }
        switch item {
        case .entry(let entry):
            return entry.playlistifiedEntry
        default:
            return nil
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        indicator = OnpuIndicatorView(frame: CGRect(x: 0,
                                                    y: 0,
                                                width: iconWidth,
                                               height: iconWidth))
        indicator.isHidden = true
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
        marginView?.removeFromSuperview()
        marginView = nil
    }

    func loadThumbnail(_ imageView: UIImageView, item: TimelineTableViewCellItem) {
        if let thumbnailUrl = item.thumbnailUrl {
            imageView.sd_setImage(with: thumbnailUrl, placeholderImage: UIImage(named: "default_thumb"))
        } else {
            imageView.image = UIImage(named: "default_thumb")
        }
    }
    
    func createImageView(_ i: Int, index: Int, item: TimelineTableViewCellItem) -> UIImageView {
        let tw = thumbnailWidth
        let rect = CGRect(x: margin + (tw + padding) * CGFloat(i), y: margin, width: tw, height: tw)
        let imageView = UIImageView(frame: rect)
        imageView.tag = index
        imageView.isUserInteractionEnabled = true
        loadThumbnail(imageView, item: item)
        switch item {
        case .track:
            imageView.addGestureRecognizer(UITapGestureRecognizer(target:self, action:#selector(TimelineTableViewCell.trackThumbImageTapped(_:))))
        case .album:
            imageView.addGestureRecognizer(UITapGestureRecognizer(target:self, action:#selector(TimelineTableViewCell.albumThumbImageTapped(_:))))
        case .playlist:
            imageView.addGestureRecognizer(UITapGestureRecognizer(target:self, action:#selector(TimelineTableViewCell.playlistThumbImageTapped(_:))))
        }
        let coverView = UIView(frame: imageView.bounds)
        coverView.backgroundColor = UIColor.imageCover
        imageView.addSubview(coverView)
        imageView.addSubview(createProviderIconImageView(item))
        imageView.addSubview(createTypeIconImageView(item, center: CGPoint(x: imageView.frame.width / 2, y: imageView.frame.height / 2)))
        return imageView
    }

    fileprivate func createProviderIconImageView(_ item: TimelineTableViewCellItem) -> UIImageView {
        let margin: CGFloat = 2.0
        let tw = thumbnailWidth
        let providerIcon = UIImageView(image: UIImage(named: item.provider.iconImageName))
        let size = item.provider.iconImageSize
        providerIcon.frame = CGRect(x: tw - size.width - margin,
                                    y: tw - size.height - margin,
                                width: size.width,
                               height: size.height)
        providerIcon.contentMode = .scaleAspectFit
        return providerIcon
    }

    fileprivate func createTypeIconImageView(_ item: TimelineTableViewCellItem, center: CGPoint) -> UIImageView {
        let typeIcon = UIImageView(image: UIImage(named: item.iconImageName)?.withRenderingMode(.alwaysTemplate))
        typeIcon.frame = CGRect(x: 0, y: 0, width: typeIconSize, height: typeIconSize)
        typeIcon.center = center
        typeIcon.tintColor = UIColor.white
        return typeIcon
    }

    func setTimelineItem(_ timelineItem: TimelineItem) {
        let tw = thumbnailWidth
        clearThumbnails()
        self.timelineItem = timelineItem
        let tracks        = timelineItem.playlist?.getTracks() ?? []
        let playlists     = timelineItem.playlists
        let albums        = timelineItem.albums
        var i = 0
        for (index, playlist) in playlists.enumerated() {
            let imageView = createImageView(i, index: index, item: .playlist(playlist))
            imageViews.append(imageView)
            thumbListContainer.addSubview(imageView)
            i += 1
        }
        for (index, album) in albums.enumerated() {
            let imageView = createImageView(i, index: index, item: .album(album))
            imageViews.append(imageView)
            thumbListContainer.addSubview(imageView)
            i += 1
        }
        for (index, track) in tracks.enumerated() {
            let imageView = createImageView(i, index: index, item: .track(track))
            imageViews.append(imageView)
            thumbListContainer.addSubview(imageView)
            i += 1
        }
        let count        = CGFloat(i)
        let widthPerPage = thumbListContainer.frame.width
        let pageNum      = Int((thumbnailWidth + padding) * count / widthPerPage) + 1
        let contentWidth = widthPerPage * CGFloat(pageNum)
        let offset       = count * (tw + padding)
        let marginView   = UIView(frame: CGRect(x: offset, y: 0.0, width: contentWidth - offset, height: thumbListContainer.frame.height))
        self.marginView  = marginView
        marginView.addGestureRecognizer(UITapGestureRecognizer(target:self, action:#selector(TimelineTableViewCell.scrollViewMarginTouched(_:))))
        thumbListContainer.addSubview(marginView)
        thumbListContainer.contentSize = CGSize(width: contentWidth, height: thumbnailWidth)
    }

    func updatePlayerIcon(_ index: Int, playerState: PlayerState) {
        let i = index + (self.timelineItem?.playlists.count ?? 0) + (self.timelineItem?.albums.count ?? 0)
        let tw = thumbnailWidth
        let htw = thumbnailWidth * 0.5
        indicator.center = CGPoint(x: margin + (tw + padding) * CGFloat(i) + htw, y: htw + margin)
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

    @objc func albumThumbImageTapped(_ sender: UITapGestureRecognizer) {
        guard let d = timelineDelegate, let album = timelineItem?.albums.get(sender.view?.tag ?? 0) else { return }
        d.albumSelected(self, album: album)
    }

    @objc func playlistThumbImageTapped(_ sender: UITapGestureRecognizer) {
        guard let d = timelineDelegate, let playlist = timelineItem?.playlists.get(sender.view?.tag ?? 0) else { return }
        d.playlistSelected(self, playlist: playlist)
    }

    @objc func trackThumbImageTapped(_ sender: UITapGestureRecognizer) {
        guard
            let playlist = timelineItem?.playlist,
            let d = timelineDelegate,
            let view = sender.view as? UIImageView else { return }
        let i = view.tag
        d.trackSelected(self, index: i, track: playlist.getTracks()[i], playlist: playlist)
    }

    @objc func scrollViewMarginTouched(_ sender: UITapGestureRecognizer) {
        timelineDelegate?.scrollViewMarginTouched(self, playlist: timelineItem?.playlist)
    }

    @objc func playButtonTouched() {
        timelineDelegate?.playButtonTouched(self)
    }

    @objc func articleButtonTouched() {
        timelineDelegate?.articleButtonTouched(self)
    }

    func observePlaylist(_ playlist: Playlist) {
        observer?.dispose()
        observer = playlist.signal.observeResult({ result in
            guard let event = result.value else { return }
            UIScheduler().schedule {
                switch event {
                case .load(let index):
                    self.loadThumbnail(self.imageViews[index], item: .track(playlist.getTracks()[index]))
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
