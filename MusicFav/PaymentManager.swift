//
//  PaymentManager.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 5/15/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import MBProgressHUD
import StoreKit
import MusicFeeder

class PaymentManager: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    let unlockEvnerythingIdentifier = "io.kumabook.MusicFav.UnlockEverything"
    enum ProductType: String {
        case UnlockEverything = "io.kumabook.MusicFav.UnlockEverything"
    }

    fileprivate static let userDefaults = UserDefaults.standard
    var productDic: [String:SKProduct] = [:]
    weak var viewController: UIViewController?
    weak var progressHUD: MBProgressHUD?
    static var isUnlockedEverything: Bool {
        get      { return userDefaults.bool(forKey: "is_unlocked_everything") }
        set(val) {
            userDefaults.set(val, forKey: "is_unlocked_everything")
            updateLimitValues()
        }
    }

    static func updateLimitValues() {
        if PaymentManager.isUnlockedEverything {
            Playlist.playlistNumberLimit = Int.max
            Playlist.trackNumberLimit    = Int.max
        } else {
            Playlist.playlistNumberLimit = 5
            Playlist.trackNumberLimit    = 5
        }
    }

    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }

    func dispose() {
        SKPaymentQueue.default().remove(self)
    }

    func showProgressHUD(for view: UIView) {
        progressHUD = MBProgressHUD.showAdded(to: view, animated: true)
    }
    func showCompleteHUD(for view: UIView) {
        progressHUD?.hide(animated: true)
        progressHUD = MBProgressHUD.showCompletedHUDForView(view, animated: true, duration: 1.0, after: {})
    }

    func hideProgressHUD() {
        progressHUD?.hide(animated: true)
        progressHUD = nil
    }

    func purchaseUnlockEverything() {
        if SKPaymentQueue.canMakePayments() {
            let productsRequest = SKProductsRequest(productIdentifiers: [unlockEvnerythingIdentifier])
            productsRequest.delegate = self
            productsRequest.start()
            if let view = viewController?.navigationController?.view {
                MBProgressHUD.showAdded(to: view, animated: true)
            }
        } else {
            let message = "Sorry. In-App Purchase is restricted".localize()
            if let vc = viewController {
                let _ = UIAlertController.show(vc, title: "MusicFav", message: message, handler: { action in })
            }
        }
    }

    func restorePurchase() {
        if SKPaymentQueue.canMakePayments() {
            SKPaymentQueue.default().restoreCompletedTransactions()
            if let view = viewController?.navigationController?.view {
                MBProgressHUD.showAdded(to: view, animated: true)
            }
        } else {
            let message = "Sorry. In-App Purchase is restricted".localize()
            if let vc = viewController {
                let _ = UIAlertController.show(vc, title: "MusicFav", message: message, handler: { action in })
            }
        }
    }

    fileprivate func purchaseProduct(_ productIdentifier: String) {
        if let type = ProductType(rawValue: productIdentifier) {
            switch type {
            case .UnlockEverything:
                PaymentManager.isUnlockedEverything = true
            }
        }
    }

    // MARK: - SKProductsRequestDelegate
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if response.invalidProductIdentifiers.count > 0 {
            if let vc = viewController {
                let _ = UIAlertController.show(vc, title: "MusicFav", message: "Invalid item identifier", handler: { action in })
            }
            return
        }

        let queue: SKPaymentQueue = SKPaymentQueue.default()
        for product in response.products {
            productDic[product.productIdentifier] = product
        }
        if let unlockEverything = productDic[unlockEvnerythingIdentifier] {
            let title = "Unlock Everything".localize()
            let description = "・Unlimited number of playlists\n・Unlimited number of tracks of per playlist".localize()
            let alert = UIAlertController(title: title,
                                        message: description,
                                 preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Purchase".localize(), style: UIAlertActionStyle.default, handler: { action in
                queue.add(SKPayment(product: unlockEverything))
            }))
            alert.addAction(UIAlertAction(title: "Cancel".localize(),
                                          style: UIAlertActionStyle.cancel,
                                        handler: { action in
                                            self.hideProgressHUD()
            }))
            viewController?.present(alert, animated: true, completion: {})
        }
    }
    // MARK: - SKPaymentTransactionObserver
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            let identifier = transaction.payment.productIdentifier
            switch transaction.transactionState {
            case .purchasing:
                if let vc = viewController, let view = vc.navigationController?.view {
                    MBProgressHUD.showAdded(to: view, animated: true)
                }
            case .purchased:
                purchaseProduct(identifier)
                queue.finishTransaction(transaction)
                if let vc = viewController, let view = vc.navigationController?.view {
                    self.hideProgressHUD()
                    if let tvc = vc as? UITableViewController {
                        tvc.tableView.reloadData()
                    }
                    showCompleteHUD(for: view)
                }
            case .failed:
                queue.finishTransaction(transaction)
                if let vc = viewController {
                    hideProgressHUD()
                    if let _ = transaction.error?.localizedDescription {
                        if let product = productDic[identifier] {
                            let title = product.localizedTitle
                            let message = String(format: "Sorry. Failed to purchase \"%@\".".localize(), title)
                            let alert = UIAlertController(title: "MusicFav", message: message, preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK".localize(), style: .cancel, handler: {action in }))
                            vc.present(alert, animated: true, completion: {})
                        }
                    }
                }
            case .restored:
                purchaseProduct(identifier)
                queue.finishTransaction(transaction)
                if let vc = viewController, let view = vc.navigationController?.view {
                    hideProgressHUD()
                    if let tvc = vc as? UITableViewController {
                        tvc.tableView.reloadData()
                    }
                    showCompleteHUD(for: view)
                }
            case .deferred:
                hideProgressHUD()
            }
        }
    }

    // Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        if let vc = viewController {
            hideProgressHUD()
            let message = String(format: "Sorry. Failed to restore.".localize())
            let alert = UIAlertController(title: "MusicFav", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK".localize(), style: .cancel, handler: {action in }))
            vc.present(alert, animated: true, completion: {})
        }
    }

    // Sent when all transactions from the user's purchase history have successfully been added back to the queue.
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        if let vc = viewController {
            hideProgressHUD()
            if let tvc = vc as? UITableViewController {
                tvc.tableView.reloadData()
            }
        }
    }
}
