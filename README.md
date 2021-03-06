# MusicFav

<img height="260" src="icon.png">

MusicFav is a Music RSS Reader that focuses on listeing music comfortably.
Currently this app is not available on App Store,
but is available via TestFlight Beta Testing.


## How to build

- Use xcode 8.1+
- Install [CocoaPods][] via `bundle install`
- Install [Carthage][] (0.18.1)
- Install dependencies with below:

  ```shell
  scripts/make.swift install
  ```
- Edit config files for third party api
    - config/feedly.json
      - You can get sandbox api key at [Feedly Cloud API][]
    - config/soundcloud.json
      - Put your [SoundCloud API][] app Client ID
    - config/fabric.json (not necessary)
      - Put your [Fabric][] api key and build secret
    - config/spotify.json (not necessary)
      - Put your [Spotify][] client id and client secret
- Open and build MusicFav.xcworkspace with xcode

[Carthage]:                 https://github.com/Carthage/Carthage
[CocoaPods]:                https://cocoapods.org/
[Feedly Cloud API]:         https://developer.feedly.com/
[SoundCloud API]:           https://developers.soundcloud.com/
[Fabric]:                   https://get.fabric.io/
[Spotify]:                  https://developer.spotify.com/
[TestFlight Beta Testing]:  http://musicfav.github.io//flight/
