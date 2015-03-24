//
//  AboutPaged.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 24.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import SwipeView

class AboutPagedViewController: UIViewController, SwipeViewDataSource, SwipeViewDelegate, UIWebViewDelegate {

    @IBOutlet weak var swipeView: SwipeView!


    @IBAction func closeButtonAction(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)


    }

    func numberOfItemsInSwipeView(swipeView: SwipeView!) -> Int {
        return 3
    }

    func swipeView(swipeView: SwipeView!, viewForItemAtIndex index: Int, reusingView view: UIView!) -> UIView! {

        if (index == 0) {
            let aboutview = self.storyboard?.instantiateViewControllerWithIdentifier("AboutViewController").view as UIView?
            aboutview?.autoresizingMask = UIViewAutoresizing.FlexibleHeight | UIViewAutoresizing.FlexibleWidth
           // aboutview?.frame = self.swipeView.bounds
            let webview = aboutview?.viewWithTag(10) as UIWebView
            webview.delegate = self
            let htmlfile = NSBundle.mainBundle().pathForResource("About", ofType: "html")
            let htmlString = String(contentsOfFile: htmlfile!, encoding: NSUTF8StringEncoding, error: nil)

            webview.loadHTMLString(htmlString, baseURL: nil)
            return aboutview
        }
        let view = UIView()
        view.autoresizingMask = UIViewAutoresizing.FlexibleHeight | UIViewAutoresizing.FlexibleWidth

        var label = UILabel(frame: view.bounds)
        label.autoresizingMask = UIViewAutoresizing.FlexibleHeight | UIViewAutoresizing.FlexibleWidth
        label.backgroundColor = UIColor.clearColor()
        label.textAlignment = NSTextAlignment.Center;
        label.tag = 1;
        view.addSubview(label)
        view.backgroundColor = UIColor.blueColor()
        label.text = String(index)
        return view
    }

    func swipeViewItemSize(swipeView: SwipeView!) -> CGSize {
        return self.swipeView.bounds.size
    }

    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        if (navigationType == UIWebViewNavigationType.LinkClicked) {
            UIApplication.sharedApplication().openURL(request.URL)
            return false
        }
        return true
    }

    override func viewDidLoad() {
        println ("viewdidload"  )
        super.viewDidLoad()
        swipeView.pagingEnabled = true
    }
}