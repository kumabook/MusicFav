//
//  Stream.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 1/12/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

@objc protocol Stream {
    var id:    String { get }
    var title: String { get }
}
