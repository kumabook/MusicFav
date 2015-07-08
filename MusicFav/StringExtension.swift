//
//  StringExtension.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/7/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation

extension String {
    func localize() -> String {
        return NSLocalizedString(self, tableName: "Localizable",
                                          bundle: NSBundle.mainBundle(),
                                           value: self,
                                         comment: self)
    }

    static func tutorialString(key: String) -> String {
        return NSLocalizedString(key, tableName: "Tutorial",
                                          bundle: NSBundle.mainBundle(),
                                           value: key,
                                         comment: key)

    }

    func toURL() -> NSURL? {
        if let url = NSURL(string: self) {
            return url
        } else if let str = stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet()) {
            return NSURL(string: str)
        }
        return nil
    }
}
