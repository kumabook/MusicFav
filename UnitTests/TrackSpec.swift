//
//  TrackSpec.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/25/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import SwiftyJSON
import Quick
import Nimble
import MusicFav

class TrackSpec: QuickSpec {
    override func spec() {
        var track: Track!
        beforeEach {
            let json = JSON(SpecHelper.fixtureJSONObject(fixtureNamed: "track")!)
            track = Track(json: json)
        }

        afterEach { TrackStore.removeAll() }

        describe("A Track") {
            it("should be constructed with json") {
                let json = JSON(SpecHelper.fixtureJSONObject(fixtureNamed: "track")!)
                let track = Track(json: json)
                expect(track).notTo(beNil())
                expect(track.provider).to(equal(Provider.Youtube))
                expect(track.identifier).to(equal("abcdefg"))
            }

            it("should be saved to persistent store") {
                var tracks = Track.findAll()
                expect(tracks.count).to(equal(0))
                TrackStore.save(track)
                tracks = Track.findAll()
                expect(tracks.count).to(equal(1))
            }
        }
    }
}
