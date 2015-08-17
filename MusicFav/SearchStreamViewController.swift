//
//  SearchStreamViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 8/15/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import FeedlyKit
import ReactiveCocoa
import MusicFeeder

class SearchStreamViewController: AddStreamTableViewController, UISearchBarDelegate {
    let SEARCH_BAR_HEIGHT: CGFloat = 40
    let reuseIdentifier = "StreamTableViewCell"
    var searchBar: UISearchBar!
    var searchDisposable: Disposable?
    var feeds:            [Feed]
    override init(streamListLoader: StreamListLoader) {
        feeds = []
        super.init(streamListLoader: streamListLoader)
    }

    required init(coder aDecoder: NSCoder) {
        feeds = []
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "StreamTableViewCell", bundle: NSBundle.mainBundle())
        tableView.registerNib(nib, forCellReuseIdentifier: reuseIdentifier)
        navigationItem.title      = "Search Feed".localize()
        searchBar                 = UISearchBar(frame:CGRectMake(0, 0, view.bounds.size.width, SEARCH_BAR_HEIGHT))
        searchBar.placeholder     = "URL or Keyword".localize()
        searchBar.delegate        = self
        tableView.tableHeaderView = searchBar
        navigationItem.leftBarButtonItem = UIBarButtonItem(title:"Back".localize(),
                                                           style: UIBarButtonItemStyle.Plain,
                                                          target: self,
                                                          action: "back")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        searchBar.becomeFirstResponder()
    }

    func back() {
        navigationController?.dismissViewControllerAnimated(true, completion: {})
    }

    override func close() {
        navigationController?.dismissViewControllerAnimated(true, completion: {})
        navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: {})
    }

    func needSearch() -> Bool{
        return searchBar.text != ""
    }

    func searchFeeds(text: String) {
        Logger.sendUIActionEvent(self, action: "searchFeeds", label: "")
        if searchDisposable != nil && !searchDisposable!.disposed {
            searchDisposable!.dispose()
        }
        feeds = []
        reloadData(keepSelection: false)
        if !needSearch() {
            return
        }
        let query = SearchQueryOfFeed(query: text)
        searchDisposable = CloudAPIClient.sharedInstance.searchFeeds(query)
            |> startOn(UIScheduler())
            |> start(
                next: { feeds in
                    self.feeds = feeds
                },
                error: { error in
                    let ac = CloudAPIClient.alertController(error: error, handler: { (action) in })
                    self.presentViewController(ac, animated: true, completion: nil)
                },
                completed: {
                    self.reloadData(keepSelection: false)
            })
    }


    // MARK: - UISearchBar delegate
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        searchFeeds(searchBar.text)
    }
    
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        searchFeeds(searchBar.text)
    }
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feeds.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath: indexPath) as! StreamTableViewCell
        setAccessoryView(cell, indexPath: indexPath)
        cell.updateView(feed: feeds[indexPath.item])
        return cell
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return self.cellHeight
    }
}

