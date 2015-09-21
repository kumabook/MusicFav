#!/usr/bin/env xcrun swift

import Darwin
import Foundation

enum Task: String {
    case Prepare = "prepare"
    case Build   = "build"
    case Test    = "test"
    case Clean   = "clean"
}

enum Target: String {
    case Production = "production"
    case Sandbox    = "sandbox"
    var feedlyConfig: String {
        switch self {
        case .Production: return "config/feedly.json.production"
        case .Sandbox:    return "config/feedly.json.sandbox"
        }
    }
    var youtubeConfig:    String { return "config/youtube.json.production" }
    var soundCloudConfig: String { return "config/soundcloud.json.production" }
    var fabricConfig:     String { return "config/fabric.json.production" }
    var gaConfig:         String {
        switch self {
        case .Production: return "config/google_analytics.json.production"
        case .Sandbox:    return "config/google_analytics.json.sandbox"
        }
    }

    var feedlyConfigDst:     String { return "config/feedly.json" }
    var youtubeConfigDst:    String { return "config/youtube.json" }
    var soundCloudConfigDst: String { return "config/soundcloud.json" }
    var fabricConfigDst:     String { return "config/fabric.json" }
    var gaConfigDst:         String { return "config/google_analytics.json" }
    func prepare() {
        run("cp \(feedlyConfig) \(feedlyConfigDst)")
        run("cp \(youtubeConfig) \(youtubeConfigDst)")
        run("cp \(soundCloudConfig) \(soundCloudConfigDst)")
        run("cp \(fabricConfig) \(fabricConfigDst)")
        run("cp \(gaConfig) \(gaConfigDst)")
    }
    func clean() {
        run("git checkout HEAD \(feedlyConfigDst)")
        run("git checkout HEAD \(youtubeConfigDst)")
        run("git checkout HEAD \(soundCloudConfigDst)")
        run("git checkout HEAD \(fabricConfigDst)")
        run("git checkout HEAD \(gaConfigDst)")
    }
    func build() {
        install_lib()
        run("xctool -workspace MusicFav.xcworkspace -scheme MusicFav archive -archivePath archives/MusicFav-`date +%Y%m%d%H%M`")
    }
    func test() {
        run("xctool -workspace MusicFav.xcworkspace -scheme UnitTests test")
    }
    func install_lib() {
        run("pod install")
        run("carthage bootstrap --use-submodules")
    }
}

func run(command: String) {
    print(command)
    system(command)
}

let feedlyConfig     = "config/feedly.json"
let youtubeConfig    = "config/youtube.json"
let soundCloudConfig = "config/soundcloud.json"
let fabricConfig     = "config/fabric.json"
let gaConfig         = "config/google_analytics.json"


let args = NSProcessInfo.processInfo().arguments as [String]
let _task   = args[args.count - 2]
let _target = args[args.count - 1]
print("------ setup config files for \(_target) --------")

if let task = Task(rawValue: _task), target = Target(rawValue:_target) {
    switch task {
    case .Prepare: target.prepare()
    case .Build:   target.prepare(); target.build()
    case .Test:    target.prepare(); target.test()
    case .Clean:   target.clean()
    }
} else {
    print("Unknown task or target")
    print("Usage: ./make task target")
    print("  task   ... prepare|build|test|clean")
    print("  target ... production|sandbox")
}

//xctool -workspace MusicFav.xcworkspace -scheme MusicFav  archive -archivePath MusicFav.ipa

