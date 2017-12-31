//
//  OAuthRequestAdapter.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2017/12/31.
//  Copyright © 2017 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import Alamofire
import OAuthSwift

open class OAuthRequestRetrier: RequestRetrier {
    
    internal let oauth: OAuth2Swift
    private let lock = NSLock()
    private var isRefreshing = false
    private var requestsToRetry: [RequestRetryCompletion] = []

    public init(_ oauth: OAuth2Swift) {
        self.oauth = oauth
    }
    public func should(_ manager: SessionManager, retry request: Request, with error: Error, completion: @escaping RequestRetryCompletion) {
        lock.lock()
        defer { lock.unlock() }
        
        if let response = request.task?.response as? HTTPURLResponse, response.statusCode == 401 {
            requestsToRetry.append(completion)
            
            if !isRefreshing {
                refreshTokens { [weak self] succeeded in
                    guard let strongSelf = self else { return }
                    strongSelf.refreshed(succeeded)
                    strongSelf.lock.lock() ; defer { strongSelf.lock.unlock() }
                    
                    strongSelf.requestsToRetry.forEach { $0(succeeded, 0.0) }
                    strongSelf.requestsToRetry.removeAll()
                }
            }
        } else {
            completion(false, 0.0)
        }
    }
    
    private typealias RefreshCompletion = (_ succeeded: Bool) -> Void
    
    private func refreshTokens(completion: @escaping RefreshCompletion) {
        guard !isRefreshing else { return }
        isRefreshing = true
        oauth.renewAccessToken(
            withRefreshToken: oauth.client.credential.oauthRefreshToken,
            success: { [weak self] (credential, response, parameters) in
                guard let strongSelf = self else { return }
                completion(true)
                strongSelf.isRefreshing = false
            }, failure: { [weak self] (error) in
                guard let strongSelf = self else { return }
                completion(false)
                strongSelf.isRefreshing = false
            }
        )
    }

    public func refreshed(_ succeeded: Bool) {}
}
