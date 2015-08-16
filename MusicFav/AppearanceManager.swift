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
        UIBarButtonItem.appearance().tintColor = UIColor.theme
        UINavigationBar.appearance().tintColor = UIColor.theme
            UIImageView.appearance().tintColor = UIColor.theme
    }
}
