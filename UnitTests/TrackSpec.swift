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

        afterEach { Track.removeAll() }

        describe("A Track") {
            it("should be constructed with json") {
                expect(track).notTo(beNil())
                expect(track.provider).to(equal(Provider.Youtube))
                expect(track.identifier).to(equal("abcdefg"))
            }

            it("should create if not exist") {
                var tracks = Track.findAll()
                expect(tracks.count).to(equal(0))
                expect(track.create()).to(equal(true))
                expect(track.create()).to(equal(false))
                tracks = Track.findAll()
                expect(tracks.count).to(equal(1))
            }

            it ("should save if exist") {
                var tracks = Track.findAll()
                expect(tracks.count).to(equal(0))
                expect(track.save()).to(equal(false))
                expect(track.create()).to(equal(true))
                expect(track.save()).to(equal(true))
            }
        }
    }
}
