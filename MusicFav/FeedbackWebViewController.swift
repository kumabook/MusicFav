//
//  FeedbackWebViewController.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 5/3/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import UIKit

class FeedbackWebViewController: UIViewController {
    var webView: UIWebView!

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Send Feedback".localize()
        navigationItem.backBarButtonItem?.title = ""
        webView = UIWebView(frame: view.frame)
        view.addSubview(webView)
        let mainBundle = Bundle.main
        if let file = mainBundle.path(forResource: "feedback_en".localize(), ofType:"html"), let data = NSData(contentsOfFile: file) {
            webView.load(data as Data, mimeType: "text/html", textEncodingName: "UTF-8", baseURL: URL(fileURLWithPath: file))
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func back() {
        let _ = navigationController?.popViewController(animated: true)
    }
}
