//
//  SpotifyAPIClient.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2016/12/04.
//  Copyright © 2016 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import SwiftyJSON
import Spotify
import SafariServices
import MusicFeeder
import ReactiveSwift
import Result

public enum SpotifyError: Error {
    case networkError(NSError)
    case notLoggedIn
    case parseError
    var title: String {
        return "Error with Spotify"
    }
    var message: String {
        switch self {
        case .notLoggedIn:
            return "Not logged in spotify"
        case .networkError(let e):
            return e.localizedDescription
        default:
            return "Sorry, unknown error occured"
        }
    }
}

open class SpotifyAPIClient: NSObject, SPTAudioStreamingDelegate {
    static var scopes       = [
        SPTAuthStreamingScope,
        SPTAuthPlaylistModifyPublicScope,
        SPTAuthPlaylistModifyPrivateScope,
        SPTAuthUserLibraryModifyScope,
        SPTAuthUserLibraryReadScope,
        SPTAuthUserFollowModifyScope,
        SPTAuthUserFollowReadScope
    ]
    static var shared       = SpotifyAPIClient()
    static var clientId        = ""
    static var clientSecret    = ""
    static var tokenSwapUrl    = ""
    static var tokenRefreshUrl = ""
    public fileprivate(set) var auth: SPTAuth!
    public let pipe = Signal<Void, NoError>.pipe()
    var player: SPTAudioStreamingController!
    var authViewController: UIViewController?
    open static func setup() {
        loadConfig()
        let auth: SPTAuth           = SPTAuth.defaultInstance()
        auth.clientID               = clientId
        auth.requestedScopes        = scopes
        auth.redirectURL            = URL(string: "io.kumabook.musicfav.spotify-auth://callback")!
        auth.tokenSwapURL           = URL(string: SpotifyAPIClient.tokenSwapUrl)!
        auth.tokenRefreshURL        = URL(string: SpotifyAPIClient.tokenRefreshUrl)!
        auth.sessionUserDefaultsKey = "SpotifySession"
        shared.auth                 = auth
        let player                  = SPTAudioStreamingController.sharedInstance() as SPTAudioStreamingController
        player.delegate             = shared
        shared.player               = player
        do {
            try shared.player.start(withClientId: auth.clientID, audioController: nil, allowCaching: true)
            shared.player.diskCache = SPTDiskCache(capacity: 1024 * 1024 * 64)
            if let accessToken = auth.session?.accessToken {
                shared.player.login(withAccessToken: accessToken)
            } else {
                print("Spotify hasn't logged in yet")
            }
        } catch {
            print("Failed to setup spotify client")
        }
    }
    fileprivate static func loadConfig() {
        let bundle = Bundle.main
        if let path = bundle.path(forResource: "spotify", ofType: "json") {
            let data = try? Data(contentsOf: URL(fileURLWithPath: path))
            let jsonObject: AnyObject? = try! JSONSerialization.jsonObject(with: data!,
                                                                           options: JSONSerialization.ReadingOptions.mutableContainers) as AnyObject?
            if let obj: AnyObject = jsonObject {
                let json = JSON(obj)
                if let id = json["client_id"].string {
                    clientId = id
                }
                if let secret = json["client_secret"].string {
                    clientSecret = secret
                }
                if let url = json["token_swap_url"].string {
                    tokenSwapUrl = url
                }
                if let url = json["token_refresh_url"].string {
                    tokenRefreshUrl = url
                }
            }
        }
    }
    var isLoggedIn: Bool {
        guard let session = auth?.session else { return false }
        return session.isValid()
    }
    func logout() {
        UserDefaults.standard.removeObject(forKey: auth.sessionUserDefaultsKey)
        auth.session = nil
        player.logout()
        pipe.input.send(value: ())
    }
    func startAuthenticationFlow(viewController: UIViewController) {
        let authURL = self.auth.spotifyWebAuthenticationURL()
        authViewController = SFSafariViewController(url: authURL!)
        viewController.present(authViewController!, animated: true, completion: nil)
    }
    func handleURL(url: URL) -> Bool {
        if auth.canHandle(url) {
            let _ = self.authViewController?.dismiss(animated: true)
            self.authViewController = nil;
            auth.handleAuthCallback(withTriggeredAuthURL: url) { (e: Error?, session: SPTSession?) in
                guard let session = session else { return }
                self.player.login(withAccessToken: session.accessToken)
                self.pipe.input.send(value: ())
            }
            return true
        }
        return false
    }
    public func audioStreamingDidLogout(_ audioStreaming: SPTAudioStreamingController!) {
        print("spotify did logout")
        Track.isSpotifyPremiumUser = false
        try? player.stop()
        auth.session = nil
    }
    public func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didReceiveError error: Error!) {
        if let e = error {
            print("spotify didReceiveError: \(e)")
        }
    }
    public func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController!) {
        print("spotify did login")
        Track.isSpotifyPremiumUser = true
    }
    #if os(iOS)
    open func open(track: Track) {
        if let url = URL(string: track.url) {
            UIApplication.shared.openURL(url)
        }
    }
    open func open(album: Album) {
        if let url = URL(string: album.url) {
            UIApplication.shared.openURL(url)
        }
    }
    open func open(playlist: ServicePlaylist) {
        if let url = URL(string: playlist.url) {
            UIApplication.shared.openURL(url)
        }
    }
    fileprivate func validate(response: URLResponse) -> SpotifyError? {
        guard let r = response as? HTTPURLResponse else {
            return  .networkError(NSError(domain: "spotify", code: 0, userInfo: ["error": "Not HTTPURLResponse"]))
        }
        if r.statusCode < 200 && r.statusCode >= 400 {
            return  .networkError(NSError(domain: "spotify", code: r.statusCode, userInfo: ["error": r.statusCode]))
        }
        return nil
    }
    open func track(from track: Track) -> SignalProducer<SPTTrack, SpotifyError> {
        return SignalProducer { (observer, disposable) in
            guard let s = self.auth.session, let accessToken = s.accessToken else {
                observer.send(error: .notLoggedIn)
                return
            }
            SPTTrack.track(withURI: track.url.toURL(), accessToken: accessToken, market: SPTMarketFromToken) { e, object in
                if let e = e as NSError? {
                    observer.send(error: .networkError(e))
                    return
                }
                if let t = object as? SPTTrack {
                    observer.send(value: t)
                    observer.sendCompleted()
                } else {
                    observer.send(error: .parseError)
                }
            }
        }
    }
    open func playlist(from url: URL) -> SignalProducer<SPTPlaylistSnapshot, SpotifyError> {
        return SignalProducer { (observer, disposable) in
            guard let s = self.auth.session, let accessToken = s.accessToken else {
                observer.send(error: .notLoggedIn)
                return
            }
            SPTPlaylistSnapshot.playlist(withURI: url, accessToken: accessToken) { e, object in
                if let e = e as NSError? {
                    observer.send(error: .networkError(e))
                    return
                }
                if let t = object as? SPTPlaylistSnapshot {
                    observer.send(value: t)
                    observer.sendCompleted()
                } else {
                    observer.send(error: .parseError)
                }
            }
        }
    }
    open func addToLibrary(track: Track) -> SignalProducer<Void, SpotifyError> {
        return self.track(from: track).flatMap(.concat) { (t: SPTTrack) -> SignalProducer<Void, SpotifyError> in
            SignalProducer { (observer, disposable) in
                guard let s = self.auth.session, let accessToken = s.accessToken else {
                    observer.send(error: .notLoggedIn)
                    return
                }
                SPTYourMusic.saveTracks([t], forUserWithAccessToken: accessToken) { e, object in
                    if let e = e as NSError? {
                        observer.send(error: .networkError(e))
                        return
                    }
                    observer.send(value: ())
                    observer.sendCompleted()
                }
            }
        }
    }
    open func add(track: Track, to playlist: SPTPartialPlaylist) -> SignalProducer<Void, SpotifyError> {
        return self.playlist(from: playlist.uri).flatMap(.concat) { (snapshot: SPTPlaylistSnapshot) -> SignalProducer<Void, SpotifyError> in
            self.track(from: track).flatMap(.concat) { (t: SPTTrack) -> SignalProducer<Void, SpotifyError> in
                SignalProducer { (observer, disposable) in
                    guard let s = self.auth.session, let accessToken = s.accessToken else {
                        observer.send(error: .notLoggedIn)
                        return
                    }
                    snapshot.addTracks(toPlaylist: [t], withAccessToken: accessToken) { error in
                        if let e = error as NSError? {
                            observer.send(error: .networkError(e))
                            return
                        }
                        observer.send(value: ())
                        observer.sendCompleted()
                    }
                }
            }
        }
    }
    open func addToLibrary(album: Album) -> SignalProducer<Void, SpotifyError> {
        return SignalProducer { (observer, disposable) in
            guard let accessToken = self.auth.session?.accessToken else {
                observer.send(error: .notLoggedIn)
                return
            }
            let url = URL(string: "https://api.spotify.com/v1/me/albums")
            let ids = [album.identifier]
            do {
                let req = try SPTRequest.createRequest(for: url, withAccessToken: accessToken, httpMethod: "PUT", values: ids, valueBodyIsJSON: true, sendDataAsQueryString: false)
                SPTRequest.sharedHandler().perform(req) { error, res, data in
                    if let e = error as NSError? {
                        observer.send(error: .networkError(e))
                        return
                    }
                    if let r = res as? HTTPURLResponse {
                        if r.statusCode < 200 && r.statusCode >= 400 {
                            observer.send(error: .networkError(NSError(domain: "spotify", code: r.statusCode, userInfo: ["error":r.statusCode])))
                            return
                        }
                    }
                    observer.send(value: ())
                    observer.sendCompleted()
                }
            } catch let error as NSError {
                observer.send(error: .networkError(error))
            }
        }
    }
    open func addToLibrary(playlist: ServicePlaylist) -> SignalProducer<Void, SpotifyError> {
        return SignalProducer { (observer, disposable) in
            guard let accessToken = self.auth.session?.accessToken else {
                observer.send(error: .notLoggedIn)
                return
            }
            do {
                let req = try SPTFollow.createRequestFor(followingPlaylist: playlist.url.toURL(), withAccessToken: accessToken, secret: false)
                SPTRequest.sharedHandler().perform(req) { error, res, data in
                    if let e = error as NSError? {
                        observer.send(error: .networkError(e))
                        return
                    }
                    if let r = res as? HTTPURLResponse {
                        if r.statusCode < 200 && r.statusCode >= 400 {
                            observer.send(error: .networkError(NSError(domain: "spotify", code: r.statusCode, userInfo: ["error":r.statusCode])))
                            return
                        }
                    }
                    observer.send(value: ())
                    observer.sendCompleted()
                }
            } catch  let error as NSError {
                observer.send(error: .networkError(error))
            }
        }
    }
    open func fetchMyPlaylists() -> SignalProducer<SPTPlaylistList, SpotifyError> {
        return SignalProducer { (observer, disposable) in
            guard let s = self.auth.session, let accessToken = s.accessToken, let name = s.canonicalUsername else {
                observer.send(error: .notLoggedIn)
                return
            }
            SPTPlaylistList.playlists(forUser: name, withAccessToken: accessToken) { e, object in
                if let e = e as NSError? {
                    observer.send(error: .networkError(e))
                    return
                }
                if let playlists = object as? SPTPlaylistList {
                    observer.send(value: playlists)
                    observer.sendCompleted()
                } else {
                    observer.send(error: .parseError)
                }
            }
        }
    }
    open class func alertController(error: SpotifyError, handler: @escaping (UIAlertAction!) -> Void) -> UIAlertController {
        let ac = UIAlertController(title: error.title.localize(),
                                   message: error.message.localize(),
                                   preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "OK".localize(), style: UIAlertActionStyle.default, handler: handler)
        ac.addAction(okAction)
        return ac
    }
    #endif
}
