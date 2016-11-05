//
//  IASKAppSettingsViewControllerExtension.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/13/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import InAppSettingsKit

extension IASKAppSettingsViewController {
    open override func viewWillAppear(_ animated: Bool) {
        navigationItem.rightBarButtonItems = []
    }
}
