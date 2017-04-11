//
//  CategoryTableViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2/18/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import ReactiveSwift
import FeedlyKit
import MusicFeeder
import MBProgressHUD

class CategoryTableViewController: UITableViewController {
    let client = CloudAPIClient.sharedInstance

    var subscribables:          [FeedlyKit.Stream]
    var subscriptionRepository: SubscriptionRepository!
    var observer:               Disposable?

    var categories: [FeedlyKit.Category] {
        let _categories   = subscriptionRepository.streamListOfCategory.keys
        var list          = [subscriptionRepository.uncategorized]
        list.append(contentsOf: _categories.filter({$0 != self.subscriptionRepository.uncategorized }))
        return list
    }

    init(subscribables: [FeedlyKit.Stream], subscriptionRepository: SubscriptionRepository) {
        self.subscribables          = subscribables
        self.subscriptionRepository = subscriptionRepository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        self.subscribables = []
        super.init(coder: aDecoder)
    }

    deinit {}

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
        navigationItem.title = "Select Category".localize()
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "add_stream"),
                                                            style: UIBarButtonItemStyle.plain,
                                                           target: self,
                                                           action: #selector(CategoryTableViewController.newCategory))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Logger.sendScreenView(self)
        observeStreamList()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        observer?.dispose()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func observeStreamList() {
        observer?.dispose()
        observer = subscriptionRepository.signal.observeResult({ result in
            guard let event = result.value else { return }
            switch event {
            case .create(_):    break
            case .startLoading: break
            case .completeLoading:
                self.tableView.reloadData()
            case .failToLoad:    break
            case .startUpdating: break
            case .failToUpdate:  break
            case .remove(_):     break
            }
        })
    }

    func newCategory() {
        Logger.sendUIActionEvent(self, action: "newCategory", label: "")
        let ac = UIAlertController(title: "New Category".localize(), message: nil, preferredStyle: UIAlertControllerStyle.alert)
        ac.addAction(UIAlertAction(title: "Cancel".localize(), style: UIAlertActionStyle.cancel, handler: { (action) -> Void in
            Logger.sendUIActionEvent(self, action: "Cancel", label: "")
        }))
        ac.addAction(UIAlertAction(title: "OK".localize(), style: UIAlertActionStyle.default, handler: { (action) -> Void in
            if let text = ac.textFields?.first?.text {
                Logger.sendUIActionEvent(self, action: "OK", label: "")
                if let category = self.subscriptionRepository.createCategory(text) {
                    self.subscribeTo(category)
                }
            }
        }))
        ac.addTextField(configurationHandler: {(text:UITextField) -> Void in
        })
        present(ac, animated: true, completion: nil)
    }

    func _subscribeTo(_ category: FeedlyKit.Category) -> SignalProducer<[Subscription], NSError> {
        return subscribables.reduce(SignalProducer(value: [])) {
            SignalProducer.combineLatest($0, subscriptionRepository.subscribeTo($1, categories: [category])).map {
                var list = $0.0; list.append($0.1); return list
            }
        }
    }

    func subscribeTo(_ category: FeedlyKit.Category) {
        MBProgressHUD.showAdded(to: self.navigationController!.view, animated: true)
        _subscribeTo(category).on(
            failed: {e in
                let _ = MBProgressHUD.hide(for: self.navigationController!.view, animated:false)
                let ac = CloudAPIClient.alertController(error: e, handler: { (action) in })
                self.present(ac, animated: true, completion: nil)
        },
            completed: {
                let _ = MBProgressHUD.showCompletedHUDForView(self.navigationController!.view, animated: true, duration: 1.0, after: {
                    self.subscriptionRepository.refresh()
                    self.navigationController?.dismiss(animated: true, completion: nil)
                })
        },
            interrupted: {},
            value: {subscriptions in
                let _ = MBProgressHUD.hide(for: self.navigationController!.view, animated:false)
        }
        ).start()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)
        if categories[indexPath.item] == subscriptionRepository.uncategorized {
            cell.textLabel?.text = categories[indexPath.item].label.localize()
        } else {
            cell.textLabel?.text = categories[indexPath.item].label
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Logger.sendUIActionEvent(self, action: "didSelectRowAtIndexPath", label: String(indexPath.row))
        subscribeTo(categories[indexPath.item])
    }
}
