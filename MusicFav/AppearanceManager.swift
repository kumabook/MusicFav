//
//  AppearanceManager.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2/24/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

class AppearanceManager {
    func apply() {
//        UINavigationBar.appearance().barTintColor = ColorHelper.themeColor
        UIBarButtonItem.appearance().tintColor = ColorHelper.themeColor
    }
}
