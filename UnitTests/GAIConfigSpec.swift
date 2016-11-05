//
//  GAIExtensionSpec.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 5/1/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Quick
import Nimble
import MusicFav

class GAIConfigSpec: QuickSpec {
    override func spec() {
        describe("A GAIExtension") {
            it("should load settings from google_analytics.json") {
                let bundle = Bundle(for: SpecHelper.self)
                GAIConfig.setup(bundle.path(forResource: "google_analytics", ofType: "json")!)
            }
        }
    }
}
