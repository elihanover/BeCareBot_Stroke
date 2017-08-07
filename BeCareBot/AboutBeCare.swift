//
//  AboutBeCare.swift
//  BeCareBot
//
//  Created by Eli Hanover on 7/11/17.
//  Copyright © 2017 BeCare. All rights reserved.
//

import UIKit
import WebKit

class AboutBeCare: UIViewController {
    
    @IBOutlet weak var tabBar: UINavigationBar!
    var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        webView = WKWebView(frame: CGRect(x: 0.0, y: self.tabBar.frame.maxY, width: view.frame.width, height: view.frame.height - self.tabBar.frame.maxY), configuration: WKWebViewConfiguration())
        self.view.addSubview(webView)
        let url = URL(string: "https://www.becarenet.net")!
        webView.load(URLRequest(url: url))
        webView.allowsBackForwardNavigationGestures = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
