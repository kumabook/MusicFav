//
//  PlaylistTableViewControllerSpec.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 5/5/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Quick
import Nimble
import KIF

class PlaylistTableViewControllerSpec: QuickSpec {
    let playlistNameElemLabel  = "Playlist name"
    let newPlaylistButtonLabel = "New Playlist"
    func transitionTo() {
        self.tester().waitForCellAtIndexPath(NSIndexPath(forItem: 0, inSection: 0), inTableViewWithAccessibilityIdentifier: "EntryStreamTableView")
        self.tester().tapViewWithAccessibilityLabel("Show playlist list")
    }
    func createNewPlaylist(name: String) {
        self.tester().tapViewWithAccessibilityLabel(newPlaylistButtonLabel)
        self.tester().enterText(name, intoViewWithAccessibilityLabel: playlistNameElemLabel)
        self.tester().tapViewWithAccessibilityLabel("OK")
    }
    func removePlaylist(name: String) {
        self.tester().swipeViewWithAccessibilityLabel(name, inDirection: KIFSwipeDirection.Left)
        self.tester().tapViewWithAccessibilityLabel("Remove")
    }
    func editTitleOfPlaylist(#from: String, to: String) {
        self.tester().swipeViewWithAccessibilityLabel(from, inDirection: KIFSwipeDirection.Left)
        self.tester().tapViewWithAccessibilityLabel("Edit title")
        self.tester().clearTextFromViewWithAccessibilityLabel(playlistNameElemLabel)
        self.tester().enterText(to, intoViewWithAccessibilityLabel: playlistNameElemLabel)
        self.tester().tapViewWithAccessibilityLabel("OK")
    }
    override func spec() {
        describe("A PlaylistTableViewController") {
            it("should create a new playlist") {
                self.transitionTo()
                let name = "test playlist"
                self.createNewPlaylist(name)
                expect(self.tester().tryFindingViewWithAccessibilityLabel(name, error: nil)).to(equal(true))
            }
            it("should remove a playlist") {
                let name = "test playlist"
                self.removePlaylist(name)
                self.tester().waitForAnimationsToFinish()
            }
            it("should edit a title of playlist") {
                let from = "test editable playlist"
                let to   = "test edited playlist"
                self.createNewPlaylist(from)
                expect(self.tester().tryFindingViewWithAccessibilityLabel(from, error: nil)).to(equal(true))
                expect(self.tester().tryFindingViewWithAccessibilityLabel(to, error: nil)).to(equal(false))
                self.editTitleOfPlaylist(from: from, to: to)
                expect(self.tester().tryFindingViewWithAccessibilityLabel(from, error: nil)).to(equal(false))
                expect(self.tester().tryFindingViewWithAccessibilityLabel(to, error: nil)).to(equal(true))
            }
        }
    }
}