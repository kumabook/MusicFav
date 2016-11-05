//
//  Error.swift
//  MusicFav
//
//  Created by KumamotoHiroki on 10/12/15.
//  Copyright © 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation

enum MusicFavError: Int {
    case entryAlreadyExists = 0

    var domain: String { return "io.kumabook.MusicFav" }
    var code:   Int {    return rawValue }

    var title: String {
        switch self {
        case .entryAlreadyExists: return "Notice"
        }
    }

    var message: String {
        switch self {
        case .entryAlreadyExists: return "This entry already saved as favorite"
        }
    }

    func alertController(_ handler: @escaping (UIAlertAction!) -> Void) -> UIAlertController {
        let ac = UIAlertController(title: title.localize(),
            message: message.localize(),
            preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "OK".localize(), style: UIAlertActionStyle.default, handler: handler)
        ac.addAction(okAction)
        return ac
    }

}
