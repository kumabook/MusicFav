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
import Alamofire
import MBProgressHUD

public enum PersonalizeTimeRange: String {
    case shortTerm  = "short_term"
    case mediumTerm = "medium_term"
    case longTerm   = "long_term"
}

public enum SpotifyError: Error {
    case networkError(NSError)
    case notLoggedIn
    case parseError
    case sessionExpired(NSError?)
    var title: String {
        return "Error with Spotify"
    }
    var message: String {
        switch self {
        case .notLoggedIn:
            return "Not logged in spotify"
        case .networkError(let e):
            return e.localizedDescription
        case .sessionExpired(_):
            return "session expired"
        default:
            return "Sorry, unknown error occured"
        }
    }
}

public struct Token {
    public var accessToken: String
    public var tokenType:   String
    public var expiresIn:   Int64
    public var expiresAt:   Int64
    init(json: JSON) {
        accessToken = json["access_token"].stringValue
        tokenType   = json["token_type"].stringValue
        expiresIn   = json["expires_in"].int64Value
        expiresAt   = Date().timestamp + expiresIn * 1000
    }
    public var isValid: Bool {
        return Date().timestamp <= expiresAt
    }
}

open class SpotifyAPIClient: NSObject, SPTAudioStreamingDelegate {
    static var scopes       = [
        SPTAuthStreamingScope,
        SPTAuthPlaylistReadPrivateScope,
        SPTAuthPlaylistModifyPublicScope,
        SPTAuthPlaylistModifyPrivateScope,
        SPTAuthUserLibraryModifyScope,
        SPTAuthUserLibraryReadScope,
        SPTAuthUserFollowModifyScope,
        SPTAuthUserFollowReadScope,
        SPTAuthUserReadPrivateScope,
        SPTAuthUserReadTopScope,
    ]
    static var shared          = SpotifyAPIClient()
    static var clientId        = ""
    static var clientSecret    = ""
    static var tokenSwapUrl    = ""
    static var tokenRefreshUrl = ""
    public fileprivate(set) var auth: SPTAuth!
    public let pipe = Signal<Void, NoError>.pipe()
    public var player: SPTAudioStreamingController!
    public var user:   SPTUser? {
        didSet {
            switch user?.product ?? .unknown {
            case .premium:
                Track.isSpotifyPremiumUser = true
            case .free, .unlimited, .unknown:
                Track.isSpotifyPremiumUser = false
            }
        }
    }
    var authViewController: UIViewController?
    var token: Token?
    var disposable: Disposable?

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
        if let session = auth.session {
            shared.renewSessionIfNeeded(session: session).startWithResult { result in
                switch result {
                case .success(let session):
                    shared.startIfUserIsPremium(with: session)
                case .failure(_):
                    print("Failed to renew session")
                }
            }
        } else {
            print("Spotify hasn't logged in yet")
        }
    }

    fileprivate static func loadConfig() {
        let bundle = Bundle.main
        if let path = bundle.path(forResource: "spotify", ofType: "json") {
            let data = try? Data(contentsOf: URL(fileURLWithPath: path))
            let jsonObject: AnyObject? = try! JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers) as AnyObject?
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
        return session.isValid() && user != nil
    }

    var accessToken: String? {
        return auth.session?.accessToken ?? token?.accessToken
    }

    func fetchTokenWithClientCredentials() -> SignalProducer<Token, SpotifyError> {
        return SignalProducer { (observer, disposable) in
            let url = "https://accounts.spotify.com/api/token"
            var headers = ["Content-Type":"application/x-www-form-urlencoded"]
            if let header = Alamofire.Request.authorizationHeader(user: SpotifyAPIClient.clientId, password: SpotifyAPIClient.clientSecret) {
                headers[header.key] = header.value
            }
            let request = Alamofire.request(url, method: .post, parameters: ["grant_type":"client_credentials"], encoding: URLEncoding.default, headers: headers)
                .authenticate(user: SpotifyAPIClient.clientId, password: SpotifyAPIClient.clientSecret)
                .responseJSON {  response in
                    if let value = response.result.value {
                        observer.send(value: Token(json: JSON(value)))
                        observer.sendCompleted()
                        return
                    }
                    if let error = response.result.error as NSError?{
                        observer.send(error: SpotifyError.networkError(error))
                    } else {
                        observer.send(error: SpotifyError.parseError)
                    }
            }
            disposable.observeEnded() {
                request.cancel()
            }
        }
    }

    func fetchTokenIfNeeded() -> SignalProducer<(), SpotifyError> {
        guard let s = auth.session, let _ = s.accessToken else {
            guard let token = token, token.isValid else {
                return fetchTokenWithClientCredentials().map {
                    self.token = $0
                    return
                }
            }
            return SignalProducer(value: ())
        }
        return renewSessionIfNeeded(session: auth.session).map {
            self.startIfUserIsPremium(with: $0)
            return
        }
    }

    func logout() {
        user = nil
        if player.loggedIn {
            player.logout()
        } else {
            didLogout()
        }
    }
    func start(with session: SPTSession) throws {
        try player.start(withClientId: auth.clientID, audioController: nil, allowCaching: true)
        player.diskCache = SPTDiskCache(capacity: 1024 * 1024 * 64)
        player.login(withAccessToken: session.accessToken)
    }
    func close() {
        try? player.stop()
        user = nil
        auth.session = nil
        UserDefaults.standard.removeObject(forKey: auth.sessionUserDefaultsKey)
        pipe.input.send(value: ())
    }
    func startAuthenticationFlow(viewController: UIViewController) {
        let authURL = self.auth.spotifyWebAuthenticationURL()
        authViewController = SFSafariViewController(url: authURL!)
        viewController.present(authViewController!, animated: true, completion: nil)
    }
    func handleURL(url: URL) -> Bool {
        var progress: MBProgressHUD?
        if auth.canHandle(url) {
            if let view = authViewController?.view {
                progress = MBProgressHUD.showAdded(to: view, animated: true)
            }
            auth.handleAuthCallback(withTriggeredAuthURL: url) { (e: Error?, session: SPTSession?) in
                let _ = self.authViewController?.dismiss(animated: true)
                self.authViewController = nil
                progress?.hide(animated: true)
                if let session = session {
                    self.startIfUserIsPremium(with: session)
                }
            }
            return true
        } else {
            let _ = self.authViewController?.dismiss(animated: true)
            self.authViewController = nil
        }
        return false
    }

    private func startIfUserIsPremium(with session: SPTSession) {
        self.disposable = self.fetchMe().on(failed: { error in
            self.close()
            self.authViewController?.dismiss(animated: true, completion: {})
            self.authViewController = nil;
            self.pipe.input.send(value: ())
        }, value: { user in
            self.user = user
            switch user.product {
            case .premium:
                do {
                    try self.start(with: session)
                } catch {
                    self.didLogin()
                }
            case .free, .unlimited, .unknown:
                self.didLogin()
            }
        }).start()
    }

    private func didLogin() {
        self.authViewController?.dismiss(animated: true, completion: {})
        self.authViewController = nil;
        self.pipe.input.send(value: ())
    }
    private func didLogout() {
        close()
        self.pipe.input.send(value: ())
    }
    public func audioStreamingDidLogout(_ audioStreaming: SPTAudioStreamingController!) {
        didLogout()
    }
    public func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didReceiveError error: Error!) {
        guard let e = error else { return }
        print("audioStreaming didReceiveError \(e)")
        disposable = renewSessionIfNeeded(session: auth.session).startWithResult { result in
            switch result {
            case .success(_):
                print("Succeeded in renewing session")
            case .failure(_):
                print("Failed to renew session")
            }
        }
    }
    public func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController!) {
        didLogin()
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
    open class func alertController(error: SpotifyError, handler: @escaping (UIAlertAction!) -> Void) -> UIAlertController {
        let ac = UIAlertController(title: error.title.localize(),
                                   message: error.message.localize(),
                                   preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "OK".localize(), style: UIAlertActionStyle.default, handler: handler)
        ac.addAction(okAction)
        return ac
    }
    public func audioStreamingDidEncounterTemporaryConnectionError(_ audioStreaming: SPTAudioStreamingController!) {
        disposable = renewSessionIfNeeded(session: auth.session).startWithResult { result in
            switch result {
            case .success(_):
                print("Succeeded in renewing session")
            case .failure(_):
                print("Failed to renew session")
            }
        }
    }

    fileprivate func validate(response: URLResponse?) -> SpotifyError? {
        guard let r = response as? HTTPURLResponse else {
            return  .networkError(NSError(domain: "spotify", code: 0, userInfo: ["error": "Not HTTPURLResponse"]))
        }
        if r.statusCode < 200 || r.statusCode >= 400 {
            return  .networkError(NSError(domain: "spotify", code: r.statusCode, userInfo: ["error": r.statusCode]))
        }
        return nil
    }

    open func renewSessionIfNeeded(session: SPTSession) -> SignalProducer<SPTSession, SpotifyError> {
        if session.isValid() {
            return SignalProducer(value: session)
        }
        return SignalProducer { (observer, disposable) in
            self.auth.renewSession(session) { error, session in
                self.auth.session = session
                if let session = session {
                    observer.send(value: session)
                } else if let error = error {
                    observer.send(error: SpotifyError.sessionExpired(error as NSError))
                } else {
                    observer.send(error: SpotifyError.sessionExpired(nil))
                }
            }
        }
    }
    #endif
    open func fetchMe() -> SignalProducer<SPTUser, SpotifyError> {
        return SignalProducer { (observer, disposable) in
            guard let s = self.auth.session, let accessToken = s.accessToken else {
                observer.send(error: .notLoggedIn)
                return
            }
            SPTUser.requestCurrentUser(withAccessToken: accessToken) { e, object in
                if let e = e as NSError? {
                    observer.send(error: .networkError(e))
                    return
                }
                if let user = object as? SPTUser {
                    observer.send(value: user)
                    observer.sendCompleted()
                } else {
                    observer.send(error: .parseError)
                }
            }
        }
    }
    open func track(from track: Track) -> SignalProducer<SPTTrack, SpotifyError> {
        return fetchTokenIfNeeded().flatMap(FlattenStrategy.concat) { () -> SignalProducer<SPTTrack, SpotifyError> in return SignalProducer { (observer, disposable) in
            guard let accessToken = self.accessToken else {
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
            }}
    }
    open func album(from url: URL) -> SignalProducer<SPTAlbum, SpotifyError> {
        return fetchTokenIfNeeded().flatMap(FlattenStrategy.concat) { () -> SignalProducer<SPTAlbum, SpotifyError> in
            return SignalProducer { (observer, disposable) in
                guard let accessToken = self.accessToken else {
                    observer.send(error: .notLoggedIn)
                    return
                }
                SPTAlbum.album(withURI: url, accessToken: accessToken, market: nil) { e, object in
                    if let e = e as NSError? {
                        observer.send(error: .networkError(e))
                        return
                    }
                    if let v = object as? SPTAlbum {
                        observer.send(value: v)
                        observer.sendCompleted()
                    } else {
                        observer.send(error: .parseError)
                    }
                }
            }
        }
    }
    open func playlist(from url: URL) -> SignalProducer<SPTPlaylistSnapshot, SpotifyError> {
        return fetchTokenIfNeeded().flatMap(FlattenStrategy.concat) { () -> SignalProducer<SPTPlaylistSnapshot, SpotifyError> in return SignalProducer { (observer, disposable) in
            guard let accessToken = self.accessToken else {
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
            }}
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
        return fetchTokenIfNeeded().flatMap(.concat) { () -> SignalProducer<Void, SpotifyError> in return SignalProducer { (observer, disposable) in
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
                    if let e = self.validate(response: res) {
                        observer.send(error: e)
                        return
                    }
                    observer.send(value: ())
                    observer.sendCompleted()
                }
            } catch  let error as NSError {
                observer.send(error: .networkError(error))
            }}
        }
    }
    open func addToLibrary(playlist: ServicePlaylist) -> SignalProducer<Void, SpotifyError> {
        return fetchTokenIfNeeded().flatMap(.concat) { () -> SignalProducer<Void, SpotifyError> in return SignalProducer { (observer, disposable) in
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
                    if let e = self.validate(response: res) {
                        observer.send(error: e)
                        return
                    }
                    observer.send(value: ())
                    observer.sendCompleted()
                }
            } catch  let error as NSError {
                observer.send(error: .networkError(error))
            }
            }}
    }
    open func removeFromLibrary(playlist: ServicePlaylist) -> SignalProducer<Void, SpotifyError> {
        return fetchTokenIfNeeded().flatMap(.concat) { () -> SignalProducer<Void, SpotifyError> in return SignalProducer { (observer, disposable) in
            guard let accessToken = self.auth.session?.accessToken else {
                observer.send(error: .notLoggedIn)
                return
            }
            do {
                let req = try SPTFollow.createRequest(forUnfollowingPlaylist: playlist.url.toURL(), withAccessToken: accessToken)
                SPTRequest.sharedHandler().perform(req) { error, res, data in
                    if let e = error as NSError? {
                        observer.send(error: .networkError(e))
                        return
                    }
                    if let e = self.validate(response: res) {
                        observer.send(error: e)
                        return
                    }
                    observer.send(value: ())
                    observer.sendCompleted()
                }
            } catch  let error as NSError {
                observer.send(error: .networkError(error))
            }
            }}
    }
    open func checkIsFollowing(playlist: ServicePlaylist) -> SignalProducer<Bool, SpotifyError> {
        return fetchTokenIfNeeded().flatMap(.concat) { () -> SignalProducer<Bool, SpotifyError> in return SignalProducer { (observer, disposable) in
            guard let accessToken = self.auth.session?.accessToken else {
                observer.send(error: .notLoggedIn)
                return
            }
            do {
                let req = try SPTFollow.createRequest(forCheckingIfUsers: [self.user!.canonicalUserName], areFollowingPlaylist: playlist.url.toURL(), withAccessToken: accessToken)
                SPTRequest.sharedHandler().perform(req) { error, res, data in
                    if let e = error as NSError? {
                        observer.send(error: .networkError(e))
                        return
                    }
                    if let e = self.validate(response: res) {
                        observer.send(error: e)
                        return
                    }
                    do {
                        let result = try SPTFollow.followingResult(from: data, with: res)
                        guard let v = result[0] as? Bool else {
                            observer.send(error: .parseError)
                            return
                        }
                        observer.send(value: v)
                    } catch let error as NSError {
                        observer.send(error: .networkError(error))
                        return
                    }
                    observer.sendCompleted()
                }
            } catch  let error as NSError {
                observer.send(error: .networkError(error))
            }
            }}
    }
    open func fetchMyPlaylists() -> SignalProducer<SPTPlaylistList, SpotifyError> {
        return fetchTokenIfNeeded().flatMap(.concat) { () -> SignalProducer<SPTPlaylistList, SpotifyError> in return SignalProducer { (observer, disposable) in
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
            }}
    }
    open func playlistsOfNextPage(_ playlistList: SPTPlaylistList) -> SignalProducer<SPTPlaylistList, SpotifyError> {
        return SignalProducer { (observer, disposable) in
            guard let s = self.auth.session, let accessToken = s.accessToken else {
                observer.send(error: .notLoggedIn)
                return
            }
            do {
                let req = try playlistList.createRequestForNextPage(withAccessToken: accessToken)
                SPTRequest.sharedHandler().perform(req) { error, res, data in
                    if let e = error as NSError? {
                        observer.send(error: .networkError(e))
                        return
                    }
                    if let e = self.validate(response: res) {
                        observer.send(error: e)
                        return
                    }
                    do {
                        let p = try SPTPlaylistList(from: data, with: res)
                        observer.send(value: p)
                    } catch let error as NSError {
                        observer.send(error: .networkError(error))
                        return
                    }
                    observer.sendCompleted()
                }
            } catch  let error as NSError {
                observer.send(error: .networkError(error))
            }
        }
    }
    open func createPlaylist(_ album: SPTAlbum) -> MusicFeeder.Playlist {
        var tracks: [MusicFeeder.Track] = []
        for item in album.firstTrackPage?.items ?? [] {
            if let track = item as? SPTPartialTrack {
                tracks.append(Track(spotifyTrack: track, spotifyAlbum: album))
            }
        }
        let playlist = MusicFeeder.Playlist(id: album.identifier, title: album.name, tracks: tracks)
        return playlist
    }
    open func createPlaylist(_ snapshot: SPTPlaylistSnapshot) -> MusicFeeder.Playlist {
        var tracks: [MusicFeeder.Track] = []
        for item in snapshot.firstTrackPage?.items ?? [] {
            if let track = item as? SPTPartialTrack {
                tracks.append(Track(spotifyTrack: track))
            }
        }
        let playlist = MusicFeeder.Playlist(id: snapshot.snapshotId, title: snapshot.name, tracks: tracks)
        return playlist
    }
    open func fetchTopTracks(_ offset: Int, limit: Int, timeRange: PersonalizeTimeRange) -> SignalProducer<SPTListPage, SpotifyError> {
        return fetchTokenIfNeeded().flatMap(.concat) { () -> SignalProducer<SPTListPage, SpotifyError> in return SignalProducer { (observer, disposable) in
            guard let s = self.auth.session, let accessToken = s.accessToken else {
                observer.send(error: .notLoggedIn)
                return
            }
            let url = URL(string: "https://api.spotify.com/v1/me/top/tracks")
            let values: [String: Any] = ["limit": limit, "offset": offset, "time_range": timeRange.rawValue]
            do {
                let req = try SPTRequest.createRequest(for: url, withAccessToken: accessToken, httpMethod: "GET", values: values, valueBodyIsJSON: true, sendDataAsQueryString: false)
                SPTRequest.sharedHandler().perform(req) { error, res, data in
                    if let e = error as NSError? {
                        observer.send(error: .networkError(e))
                        return
                    }
                    if let e = self.validate(response: res) {
                        observer.send(error: e)
                        return
                    }
                    do {
                        let page = try SPTListPage(from: data, with: res, expectingPartialChildren: false, rootObjectKey: nil)
                        observer.send(value: page)
                        observer.sendCompleted()
                    } catch let error as NSError {
                        observer.send(error: .networkError(error))
                    }
                }
            } catch let error as NSError {
                observer.send(error: .networkError(error))
            }}
        }
    }
}
