#!/usr/bin/env xcrun swift

import Darwin
import Foundation

extension String {
    func trim() -> String
    {
        return self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}

let git        = "/usr/local/bin/"
let cp         = "/bin/cp"
let xcodebuild = "/usr/bin/xcodebuild"
let carthage   = "/usr/local/bin/carthage"
let agvtool    = "/usr/bin/agvtool"
let version    = "0.5.1"

enum Task: String {
    case Config  = "config"
    case Prepare = "prepare"
    case Build   = "build"
    case Test    = "test"
    case Clean   = "clean"
    case Version = "next-version"
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

    // fastlane
    var deliverfile: String { return "fastlane/Deliverfile.production" }
    var appfile:     String { return "fastlane/Appfile.production" }

    var feedlyConfigDst:     String { return "config/feedly.json" }
    var youtubeConfigDst:    String { return "config/youtube.json" }
    var soundCloudConfigDst: String { return "config/soundcloud.json" }
    var fabricConfigDst:     String { return "config/fabric.json" }
    var gaConfigDst:         String { return "config/google_analytics.json" }
    var deliverfileDst:      String { return "fastlane/Deliverfile" }
    var appfileDst:          String { return "fastlane/Appfile" }
    func config() {
        print("------ setup config files for \(self) --------")
        let _ = shell(cp, args: "\(feedlyConfig)"    , "\(feedlyConfigDst)")
        let _ = shell(cp, args: "\(youtubeConfig)"   , "\(youtubeConfigDst)")
        let _ = shell(cp, args: "\(soundCloudConfig)", "\(soundCloudConfigDst)")
        let _ = shell(cp, args: "\(fabricConfig)"    , "\(fabricConfigDst)")
        let _ = shell(cp, args: "\(deliverfile)"     , "\(deliverfileDst)")
        let _ = shell(cp, args: "\(appfile)"         , "\(appfileDst)")
    }
    func prepare() {
        install_lib()
    }
    func clean() {
        let _ = shell(git, args: "checkout", "HEAD", "\(feedlyConfigDst)")
        let _ = shell(git, args: "checkout", "HEAD", "\(youtubeConfigDst)")
        let _ = shell(git, args: "checkout", "HEAD", "\(soundCloudConfigDst)")
        let _ = shell(git, args: "checkout", "HEAD", "\(fabricConfigDst)")
        let _ = shell(git, args: "checkout", "HEAD", "\(gaConfigDst)")
        let _ = shell(git, args: "checkout", "HEAD", "\(deliverfileDst)")
        let _ = shell(git, args: "checkout", "HEAD", "\(appfileDst)")
    }
    func build() {
        let _ = shell(xcodebuild, args: "-workspace", "MusicFav.xcworkspace", "-scheme", "MusicFav", "archive", "-archivePath", "archives/MusicFav-`date +%Y%m%d%H%M`")
    }
    func test() {
        let _ = shell(xcodebuild, args: "-workspace", "MusicFav.xcworkspace", "-scheme", "UnitTests", "test")
    }
    func install_lib() {
        let _ = shell("bundle", args: "install")
        let _ = shell("bundle", args: "exec", "pod", "install")
        switch self {
        case .Production:
          let _ = shell(carthage, args: "checkout", "--use-submodules", "--use-ssh", "--no-use-binaries")
          let _ = shell(carthage, args: "build", "--platform", "iOS", "--configuration", "Release")
        case .Sandbox:
          let _ = shell(carthage, args: "checkout", "--use-submodules", "--use-ssh", "--no-use-binaries")
          let _ = shell(carthage, args: "build", "--platform", "iOS", "--configuration", "Debug")
        }
    }
}

func shell(_ command : String, args : String...) -> String {
    var output: [String] = []
    
    let task = Process()
    task.launchPath = command
    task.arguments = args
    
    let outpipe = Pipe()
    task.standardOutput = outpipe
    let errpipe = Pipe()
    task.standardError = errpipe
    
    task.launch()
    
    let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
    if var string = String(data: outdata, encoding: .utf8) {
        string = string.trimmingCharacters(in: .newlines)
        output = string.components(separatedBy: "\n")
    }
    
    let errdata = errpipe.fileHandleForReading.readDataToEndOfFile()
    if var string = String(data: errdata, encoding: .utf8) {
        string = string.trimmingCharacters(in: .newlines)
    }
    
    task.waitUntilExit()
    let _ = task.terminationStatus
    
    return output[0]
}

func showUsage() {
    print("Unknown task or target")
    print("Usage: ./make task target")
    print("  task   ... config|prepare|build|test|clean|next-version")
    print("  target ... production|sandbox")
}

func nextVersion() {
    print("-------- increment versions --------")
    guard let currentVersion = Int(shell(agvtool, args: "what-version", "-terse").trim()) else {
      print("Failed to get currentVersion")
      return
    }
    let _ = shell(agvtool, args: "next-version", "-all")
    print("update bundle version: \(currentVersion) -> \(currentVersion + 1)")
    print("-------- update version strings  --------")
    let _ = shell(agvtool, args: "new-marketing-version", "\(version)")
}

func main(task: Task, target: Target) {
    switch task {
    case .Config:  target.config()
    case .Prepare: target.prepare()
    case .Build:   target.config(); target.build()
    case .Test:    target.test()
    case .Clean:   target.clean()
    case .Version: nextVersion()
    }
}

let feedlyConfig     = "config/feedly.json"
let youtubeConfig    = "config/youtube.json"
let soundCloudConfig = "config/soundcloud.json"
let fabricConfig     = "config/fabric.json"
let gaConfig         = "config/google_analytics.json"

let args = ProcessInfo.processInfo.arguments as [String]
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

