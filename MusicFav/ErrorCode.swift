//
//  ErrorCode.swift
//  MusicFav
//
//  Created by KumamotoHiroki on 10/12/15.
//  Copyright © 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation

enum Error: Int {
    case EntryAlreadyExists = 0

    var domain: String { return "io.kumabook.MusicFav" }
    var code:   Int {    return rawValue }

    var title: String {
        switch self {
        case EntryAlreadyExists: return "Notice"
        }
    }

    var message: String {
        switch self {
        case EntryAlreadyExists: return "This entry already saved as favorite"
        }
    }

    func alertController(handler: (UIAlertAction!) -> Void) -> UIAlertController {
        let ac = UIAlertController(title: title.localize(),
            message: message.localize(),
            preferredStyle: UIAlertControllerStyle.Alert)
        let okAction = UIAlertAction(title: "OK".localize(), style: UIAlertActionStyle.Default, handler: handler)
        ac.addAction(okAction)
        return ac
    }

}