#!/usr/bin/env xcrun swift

import Darwin
import Foundation

enum Task: String {
    case Config  = "config"
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
    func config() {
        print("------ setup config files for \(self) --------")
        run("cp \(feedlyConfig) \(feedlyConfigDst)")
        run("cp \(youtubeConfig) \(youtubeConfigDst)")
        run("cp \(soundCloudConfig) \(soundCloudConfigDst)")
        run("cp \(fabricConfig) \(fabricConfigDst)")
        run("cp \(gaConfig) \(gaConfigDst)")
    }
    func prepare() {
        install_lib()
    }
    func clean() {
        run("git checkout HEAD \(feedlyConfigDst)")
        run("git checkout HEAD \(youtubeConfigDst)")
        run("git checkout HEAD \(soundCloudConfigDst)")
        run("git checkout HEAD \(fabricConfigDst)")
        run("git checkout HEAD \(gaConfigDst)")
    }
    func build() {
        run("xctool -workspace MusicFav.xcworkspace -scheme MusicFav archive -archivePath archives/MusicFav-`date +%Y%m%d%H%M`")
    }
    func test() {
        run("xctool -workspace MusicFav.xcworkspace -scheme UnitTests test")
    }
    func install_lib() {
        run("bundle install")
        run("bundle exec pod install")
        let options = "--use-submodules --use-ssh --platform iOS --no-use-binaries"
        switch self {
        case .Production:
          run("carthage bootstrap \(options) --configuration Release")
        case .Sandbox:
          run("carthage bootstrap \(options) --configuration Debug")
        }
    }
}

func run(command: String) {
    print(command)
    system(command)
}

func showUsage() {
    print("Unknown task or target")
    print("Usage: ./make task target")
    print("  task   ... config|prepare|build|test|clean")
    print("  target ... production|sandbox")
}

func main(task task: Task, target: Target) {
    switch task {
    case .Config:  target.config()
    case .Prepare: target.prepare()
    case .Build:   target.config(); target.build()
    case .Test:    target.test()
    case .Clean:   target.clean()
    }
}

let feedlyConfig     = "config/feedly.json"
let youtubeConfig    = "config/youtube.json"
let soundCloudConfig = "config/soundcloud.json"
let fabricConfig     = "config/fabric.json"
let gaConfig         = "config/google_analytics.json"

let args = NSProcessInfo.processInfo().arguments as [String]
var _task   = args[args.count - 2]
var _target = args[args.count - 1]
if _task == "--" {
   _task = _target
}
if let task = Task(rawValue: _task) {
    if let target = Target(rawValue:_target) {
         main(task: task, target: target)
    } else {
        if task != .Config {
            main(task: task, target: .Production)
        } else {
            showUsage()
        }
    }
} else {
    showUsage()
}

//xctool -workspace MusicFav.xcworkspace -scheme MusicFav  archive -archivePath MusicFav.ipa

