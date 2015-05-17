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

class PaymentManager: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    let unlockEvnerythingIdentifier = "io.kumabook.MusicFav.UnlockEverything"
    enum ProductType: String {
        case UnlockEverything = "io.kumabook.MusicFav.UnlockEverything"
    }

    private static let userDefaults = NSUserDefaults.standardUserDefaults()
    var productDic: [String:SKProduct] = [:]
    weak var viewController: UITableViewController?
    static var isUnlockedEverything: Bool {
        get      { return userDefaults.boolForKey("is_unlocked_everything") }
        set(val) { userDefaults.setBool(val, forKey: "is_unlocked_everything") }
    }

    override init() {
        super.init()
        SKPaymentQueue.defaultQueue().addTransactionObserver(self)
    }

    func dispose() {
        SKPaymentQueue.defaultQueue().removeTransactionObserver(self)
    }

    func purchaseUnlockEverything() {
        if SKPaymentQueue.canMakePayments() {
            var productsRequest = SKProductsRequest(productIdentifiers: [unlockEvnerythingIdentifier])
            productsRequest.delegate = self
            productsRequest.start()
            if let view = viewController?.navigationController?.view {
                MBProgressHUD.showHUDAddedTo(view, animated: true)
            }
        } else {
            let message = "Sorry. In-App Purchase is restricted".localize()
            if let vc = viewController {
                UIAlertController.show(vc, title: "MusicFav", message: message, handler: { action in })
            }
        }
    }

    private func purchaseProduct(product: SKProduct) {
        if let type = ProductType(rawValue: product.productIdentifier) {
            switch type {
            case .UnlockEverything:
                PaymentManager.isUnlockedEverything = true
            }
        }
    }

    // MARK: - SKProductsRequestDelegate
    func productsRequest(request: SKProductsRequest!, didReceiveResponse response: SKProductsResponse!) {
        if response.invalidProductIdentifiers.count > 0 {
            if let vc = viewController {
                UIAlertController.show(vc, title: "MusicFav", message: "Invalid item identifier", handler: { action in })
            }
            return
        }

        var queue: SKPaymentQueue = SKPaymentQueue.defaultQueue()
        if let products = response.products as? [SKProduct] {
            for product in products {
                productDic[product.productIdentifier] = product
            }
        }
        if let unlockEverything = productDic[unlockEvnerythingIdentifier] {
            var alert = UIAlertController(title: "MusicFav",
                                        message: unlockEverything.localizedTitle + "\n" + unlockEverything.localizedDescription,
                                 preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Purchase".localize(), style: UIAlertActionStyle.Default, handler: { action in
                queue.addPayment(SKPayment(product: unlockEverything))
            }))
            alert.addAction(UIAlertAction(title: "Cancel".localize(),
                                          style: UIAlertActionStyle.Cancel,
                                        handler: { action in
                                            if let vc = self.viewController, view = vc.navigationController?.view {
                                                MBProgressHUD.hideAllHUDsForView(view, animated: true)
                                            }
            }))
            viewController?.presentViewController(alert, animated: true, completion: {})
        }
    }
    // MARK: - SKPaymentTransactionObserver
    func paymentQueue(queue: SKPaymentQueue!, updatedTransactions transactions: [AnyObject]!) {
        for transaction in transactions as! [SKPaymentTransaction] {
            let identifier = transaction.payment.productIdentifier
            if let product = productDic[identifier], title = product.localizedTitle, desc = product.localizedDescription {
                switch transaction.transactionState {
                case .Purchasing:
                    if let vc = viewController, view = vc.navigationController?.view {
                        MBProgressHUD.showHUDAddedTo(view, animated: true)
                    }
                case .Purchased:
                    purchaseProduct(product)
                    if let vc = viewController, view = vc.navigationController?.view {
                        MBProgressHUD.hideAllHUDsForView(view, animated: true)
                        vc.tableView.reloadData()
                        MBProgressHUD.showCompletedHUDForView(view, animated: true, duration: 1.0, after: {
                            queue.finishTransaction(transaction)
                        })
                    }
                case .Failed:
                    queue.finishTransaction(transaction)
                    if let vc = viewController, view = vc.navigationController?.view {
                        MBProgressHUD.hideAllHUDsForView(view, animated: true)
                        if transaction.error.code != SKErrorPaymentCancelled {
                            let message = String(format: "Sorry. Failed to purchase \"%@\".".localize(), title)
                            var alert = UIAlertController(title: "MusicFav", message: message, preferredStyle: .Alert)
                            alert.addAction(UIAlertAction(title: "OK".localize(), style: .Cancel, handler: {action in }))
                            vc.presentViewController(alert, animated: true, completion: {})
                        }
                    }
                case .Restored:
                    purchaseProduct(product)
                    if let vc = viewController, view = vc.navigationController?.view {
                        MBProgressHUD.hideAllHUDsForView(view, animated: true)
                        vc.tableView.reloadData()
                        MBProgressHUD.showCompletedHUDForView(view, animated: true, duration: 1.0, after: {
                            queue.finishTransaction(transaction)
                        })
                    }
                case .Deferred:
                    if let vc = viewController, view = vc.navigationController?.view {
                        MBProgressHUD.hideAllHUDsForView(view, animated: true)
                    }
                }
            }
        }
    }
}