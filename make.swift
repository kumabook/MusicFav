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
        case .Production: return "MusicFav/feedly.json.production"
        case .Sandbox:    return "MusicFav/feedly.json.sandbox"
        }
    }
    var soundCloudConfig: String { return "MusicFav/soundcloud.json.production" }
    var fabricConfig:     String { return "MusicFav/fabric.json.production" }

    var feedlyConfigDst:     String { return "MusicFav/feedly.json" }
    var soundCloudConfigDst: String { return "MusicFav/soundcloud.json" }
    var fabricConfigDst:     String { return "MusicFav/fabric.json" }
    func prepare() {
        run("cp \(feedlyConfig) \(feedlyConfigDst)")
        run("cp \(soundCloudConfig) \(soundCloudConfigDst)")
        run("cp \(fabricConfig) \(fabricConfigDst)")
    }
    func clean() {
        run("git checkout HEAD \(feedlyConfigDst)")
        run("git checkout HEAD \(soundCloudConfigDst)")
        run("git checkout HEAD \(fabricConfigDst)")
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
    println(command)
    system(command)
}

let feedlyConfig     = "MusicFav/feedly.json"
let soundCloudConfig = "MusicFav/soundcloud.json"
let fabricConfig     = "MusicFav/fabric.json"


let args = NSProcessInfo.processInfo().arguments as! [String]
let _task   = args[args.count - 2]
let _target = args[args.count - 1]
println("------ setup config files for \(_target) --------")

if let task = Task(rawValue: _task), target = Target(rawValue:_target) {
    switch task {
    case .Prepare: target.prepare()
    case .Build:   target.prepare(); target.build()
    case .Test:    target.prepare(); target.test()
    case .Clean:   target.clean()
    }
} else {
    println("Unknown task or target")
    println("Usage: ./make task target")
    println("  task   ... prepare|build|test|clean")
    println("  target ... production|sandbox")
}

//xctool -workspace MusicFav.xcworkspace -scheme MusicFav  archive -archivePath MusicFav.ipa

