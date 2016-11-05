//
//  SpecHelper.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/25/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation

open class SpecHelper {
    open class func fixtureJSONObject(fixtureNamed: String) -> AnyObject? {
        let bundle   = Bundle(for: SpecHelper.self)
        let filePath = bundle.path(forResource: fixtureNamed, ofType: "json")
        let data     = try? Data(contentsOf: URL(fileURLWithPath: filePath!))
        let jsonObject : AnyObject? = try! JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers) as AnyObject?
        return jsonObject
    }
}

