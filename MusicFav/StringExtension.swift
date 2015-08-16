//
//  StringExtension.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/7/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation

extension String {
    static func tutorialString(key: String) -> String {
        return NSLocalizedString(key, tableName: "Tutorial",
                                          bundle: NSBundle.mainBundle(),
                                           value: key,
                                         comment: key)

    }
}
