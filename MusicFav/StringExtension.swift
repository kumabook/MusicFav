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
}
