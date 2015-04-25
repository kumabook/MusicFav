//
//  FabricConfig.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/26/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import SwiftyJSON

public class FabricConfig {
    private static let defaultApiKey = "api_key"
    public let apiKey:      String
    public let buildSecret: String
    public var skip: Bool {
        return apiKey == FabricConfig.defaultApiKey
    }
    public init(filePath: String) {
        let data                   = NSData(contentsOfFile: filePath)
        let jsonObject: AnyObject? = NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers, error: nil)
        let json                   = JSON(jsonObject!)
        apiKey                     = json["api_key"].stringValue
        buildSecret                = json["build_secret"].stringValue
    }
}
