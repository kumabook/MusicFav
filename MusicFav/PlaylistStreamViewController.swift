//
//  PlaylistStreamViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/4/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import LlamaKit
import SwiftyJSON
import FeedlyKit

class PlaylistStreamViewController: UITableViewController, PlaylistStreamTableViewCellDelegate {
    let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
    let cellHeight: CGFloat = 120
    let playlistStreamTableCellReuseIdentifier = "PlaylistStreamTableViewCell"

    var indicator:    UIActivityIndicatorView!
    var reloadButton: UIButton!
    var streamLoader: StreamLoader!

    init(streamLoader: StreamLoader) {
        self.streamLoader = streamLoader
        super.init(nibName: nil, bundle: nil)
    }

    override init(style: UITableViewStyle) {
        super.init(style: style)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
    }

    override func loadView() {
        super.loadView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "PlaylistStreamTableViewCell", bundle: nil)
        tableView.registerNib(nib, forCellReuseIdentifier: playlistStreamTableCellReuseIdentifier)
        clearsSelectionOnViewWillAppear = true

        indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
        indicator.bounds = CGRect(x: 0,
            y: 0,
            width: indicator.bounds.width,
            height: indicator.bounds.height * 3)
        indicator.hidesWhenStopped = true
        indicator.stopAnimating()

        reloadButton = UIButton()
        reloadButton.setImage(UIImage(named: "network_error"), forState: UIControlState.Normal)
        reloadButton.setTitleColor(UIColor.blackColor(), forState: UIControlState.Normal)
        reloadButton.addTarget(self, action:"fetchEntries", forControlEvents:UIControlEvents.TouchUpInside)
        reloadButton.setTitle("Sorry, network error occured.", forState:UIControlState.Normal)
        reloadButton.frame = CGRectMake(0, 0, tableView.frame.size.width, 44);

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action:"fetchLatestEntries", forControlEvents:UIControlEvents.ValueChanged)
        observeStreamLoader()
    }

    override func viewWillDisappear(animated: Bool) {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "logout", object: nil)
        super.viewWillDisappear(animated)
    }

    func observeStreamLoader() {
        streamLoader.hotSignal.observe({ event in
            switch event {
            case .StartLoadingLatest:
                self.refreshControl?.beginRefreshing()
            case .CompleteLoadingLatest:
                self.tableView.reloadData()
                self.refreshControl?.endRefreshing()
            case .StartLoadingNext:
                self.showIndicator()
            case .CompleteLoadingNext:
                self.hideIndicator()
                self.tableView.reloadData()
            case .FailToLoadNext:
                self.showReloadButton()
            case .CompleteLoadingPlaylist(let playlist, let entry):
                if let i = find(self.streamLoader.entries, entry) {
                    if i < self.tableView.numberOfRowsInSection(0) {
                        let index = NSIndexPath(forItem: i, inSection: 0)
                        self.tableView.reloadRowsAtIndexPaths([index], withRowAnimation: UITableViewRowAnimation.None)
                    }
                }
            case .RemoveAt(let index):
                let indexPath = NSIndexPath(forItem: index, inSection: 0)
                self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            }
        })

        tableView?.reloadData()
        streamLoader.fetchEntries()
        let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        appDelegate.miniPlayerViewController?.mainViewController.showCenterPanelAnimated(true)
    }

    func showPlaylist() {
        let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        appDelegate.miniPlayerViewController?.mainViewController.showRightPanelAnimated(true)
    }

    func fetchLatestEntries() {
        streamLoader.fetchLatestEntries()
    }

    func showIndicator() {
        self.tableView.tableFooterView = indicator
        indicator?.startAnimating()
    }

    func hideIndicator() {
        indicator?.stopAnimating()
        self.tableView.tableFooterView = nil
    }

    func showReloadButton() {
        self.tableView.tableFooterView = reloadButton
    }

    func hideReloadButton() {
        self.tableView.tableFooterView = nil
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - PlaylistStreamTableViewDelegate

    func trackSelectedAt(index: Int, track: Track, playlist: Playlist) {
        appDelegate.miniPlayerViewController?.play(index, playlist: playlist)
    }

    // MARK: - Table view data source

    override func scrollViewDidScroll(scrollView: UIScrollView) {
        if tableView.contentOffset.y >= tableView.contentSize.height - tableView.bounds.size.height {
            streamLoader.fetchEntries()
        }
    }

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return streamLoader.entries.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let entry = streamLoader.entries[indexPath.row]
        let cell = tableView.dequeueReusableCellWithIdentifier(playlistStreamTableCellReuseIdentifier, forIndexPath:indexPath) as PlaylistStreamTableViewCell
        cell.titleLabel.text = entry.title
        if let playlist = streamLoader.playlistsOfEntry[entry] {
            cell.delegate           = self
            cell.trackNumLabel.text = "\(playlist.tracks.count) tracks"
            cell.loadThumbnails(playlist)
            cell.observePlaylist(playlist)
        } else {
            cell.trackNumLabel.text = "? tracks"
        }
        return cell
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return self.cellHeight
    }
}
