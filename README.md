# MusicFav

<img height="260" src="icon.png">

MusicFav is a Music RSS Reader that focuses on listeing music comfortably.
Currently this app is not available on App Store,
but is available via TestFlight Beta Testing.


## How to build

- Use xcode 6.3
- Install [Carthage][] and [CocoaPods][]
- Install dependencies with below:
  ```shell
  carthage bootstrap --use-submodule
  pod install
  ```
- Edit config files for third party api
    - MusicFav/feedly.json
      - You can get sandbox api key at [Feedly Cloud API][]
    - MusicFav/soundcloud.json
      - Put your [SoundCloud API][] app Client ID
    - MusicFav/fabric.json (not necessary)
      - Put your [Fabric][] api key and build secret
- Open and build MusicFav.xcworkspace with xcode

[Carthage]:                https://github.com/Carthage/Carthage
[CocoaPods]:               https://cocoapods.org/
[Feedly Cloud API]:        https://developer.feedly.com/
[SoundCloud API]:          https://developers.soundcloud.com/
[Fabric]:                  https://get.fabric.io/
[TestFlight Beta Testing]: http://musicfav.github.io//flight/
