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
import LlamaKit


protocol PlaylistStreamTableViewCellDelegate {
    func trackSelectedAt(index: Int, track: Track, playlist: Playlist)
    func trackScrollViewMarginTapped(playlist: Playlist?)
}

class PlaylistStreamTableViewCell: UITableViewCell {
    let thumbnailWidth: CGFloat = 60.0

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var trackThumbScrollView: UIScrollView!

    var imageViews: [UIImageView] = []
    var playlist:   Playlist?
    var delegate:   PlaylistStreamTableViewCellDelegate?
    var observer:   Disposable?

    @IBOutlet weak var trackNumLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    deinit {
        if let _observer = observer {
            _observer.dispose()
            observer = nil
        }
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
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
        for imageView in imageViews {
            imageView.sd_cancelCurrentImageLoad()
            imageView.removeFromSuperview()
        }
        self.playlist = playlist
        imageViews = []
        for (i, track) in enumerate(playlist.tracks) {
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

    func thumbImageTapped(sender: UITapGestureRecognizer) {
        if let playlist = self.playlist {
            if let delegate = self.delegate {
                if let view = sender.view as? UIImageView {
                    if let i = find(imageViews, view) {
                        delegate.trackSelectedAt(i, track: playlist.tracks[i], playlist: playlist)
                    }
                }
            }
        }
    }

    func trackScrollViewMarginTapped(sender: UITapGestureRecognizer) {
        delegate?.trackScrollViewMarginTapped(self.playlist)
    }

    func observePlaylist(playlist: Playlist) {
        if let _observer = observer {
            _observer.dispose()
        }
        observer = playlist.signal.observe { index in
            MainScheduler().schedule {
                self.loadThumbnail(self.imageViews[index], track: playlist.tracks[index])
            }
            return
        }
    }
}
