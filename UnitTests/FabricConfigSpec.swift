//
//  FabricConfigSpec.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/26/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Quick
import Nimble
import MusicFav

class FabricConfigSpec: QuickSpec {
    override func spec() {
        describe("A FabricConfig") {
            it("should set the skip flag if fabric json is as default") {
                let bundle = Bundle(for: SpecHelper.self)
                let config = FabricConfig(filePath: bundle.path(forResource: "fabric_invalid", ofType: "json")!)
                expect(config.apiKey).to(equal("api_key"))
                expect(config.buildSecret).to(equal("build_secret"))
                expect(config.skip).to(equal(true))
            }
            it("should unset the skip flag if fabric json is set") {
                let bundle = Bundle(for: SpecHelper.self)
                let config = FabricConfig(filePath: bundle.path(forResource: "fabric_valid", ofType: "json")!)
                expect(config.apiKey).to(equal("123456789"))
                expect(config.buildSecret).to(equal("123456789"))
                expect(config.skip).to(equal(false))
            }

        }
    }
}
