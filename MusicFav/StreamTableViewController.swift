//
//  StreamTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 1/3/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveCocoa
import LlamaKit
import FeedlyKit

class StreamTableViewController: UITableViewController, UISearchBarDelegate {
    let SEARCH_BAR_HEIGHT: CGFloat = 40
    enum Section: Int {
        case SearchResult = 0
        static let count  = 1
        var title: String? {
            get {
                switch self {
                case .SearchResult:
                    return nil
                default:
                    return nil
                }
            }
        }
    }
    let client = FeedlyAPIClient.sharedInstance
    var searchDisposable: Disposable?
    var isLoggedIn: Bool {
        get {
            return client.account != nil
        }
    }
    var feeds: [Feed] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
        navigationItem.leftBarButtonItem = UIBarButtonItem(title:"close",
                                                           style: UIBarButtonItemStyle.Plain,
                                                          target: self,
                                                          action: "close")
        let searchBar                  = UISearchBar(frame:CGRectMake(0, 0, view.bounds.size.width, SEARCH_BAR_HEIGHT))
        searchBar.placeholder          = "URL or keyword"
        searchBar.delegate             = self
        self.tableView.tableHeaderView = searchBar
        self.navigationItem.title      = "Import to MusicFav"        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func searchFeeds(text: String) {
        if searchDisposable != nil && !searchDisposable!.disposed {
            searchDisposable!.dispose()
        }
        feeds = []
        tableView.reloadData()
        if text.lengthOfBytesUsingEncoding(NSStringEncoding.allZeros) == 0 {
            return
        }
        let query = SearchQueryOfFeed(query: text)
        searchDisposable = client.searchFeeds(query)
            .deliverOn(MainScheduler())
            .start(
                next: {feeds in
                    self.feeds = feeds
                },
                error: {error in
                    let ac = FeedlyAPIClient.alertController(error: error, handler: { (action) in })
                    self.presentViewController(ac, animated: true, completion: nil)
                },
                completed: {
                    self.tableView.reloadData()
            })
    }

    // MARK: - UISearchBarDelegate delegate

    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        searchFeeds(searchBar.text)
    }

    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        searchFeeds(searchBar.text)
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return Section.count
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (Section(rawValue: section)!) {
        case .SearchResult:
            return feeds.count
        }
    }


    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath) as UITableViewCell
        if let searchResultsTableView = searchDisplayController?.searchResultsTableView {
            if tableView == searchResultsTableView {
                println("search results")
            }
        }
        switch Section(rawValue: indexPath.section)! {
        case .SearchResult:
            let feed = feeds[indexPath.item]
            cell.textLabel?.text = "\(feed.title) \(feed.subscribers) subscribers"
        default:
            break
        }
        return cell
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let feed = feeds[indexPath.item]
        if isLoggedIn {
            let ctc = CategoryTableViewController()
            ctc.feed = feed
            navigationController?.pushViewController(ctc, animated: true)
        }
    }

    func close() {
        self.navigationController?.dismissViewControllerAnimated(true, nil)
    }
}
