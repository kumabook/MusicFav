//
//  FabricConfig.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/26/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import SwiftyJSON

open class FabricConfig {
    fileprivate static let defaultApiKey = "api_key"
    open let apiKey:      String
    open let buildSecret: String
    open var skip: Bool {
        return apiKey == FabricConfig.defaultApiKey
    }
    public init(filePath: String) {
        let data                   = try? Data(contentsOf: URL(fileURLWithPath: filePath))
        let jsonObject: AnyObject? = try! JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers) as AnyObject?
        let json                   = JSON(jsonObject!)
        apiKey                     = json["api_key"].stringValue
        buildSecret                = json["build_secret"].stringValue
    }
}
