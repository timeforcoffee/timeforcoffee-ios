//
//  AboutPaged.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 24.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import SwipeView

final class AboutPagedViewController: UIViewController, SwipeViewDataSource, SwipeViewDelegate, UIWebViewDelegate {

    @IBOutlet weak var swipeView: SwipeView!

    @IBOutlet weak var bgImage: UIImageView!

    @IBOutlet weak var bgImageLeft: NSLayoutConstraint!
    @IBAction func closeButtonAction(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    func numberOfItemsInSwipeView(swipeView: SwipeView!) -> Int {
        return 1
    }

    func swipeView(swipeView: SwipeView!, viewForItemAtIndex index: Int, reusingView view: UIView!) -> UIView! {

        if (index == 0) {
            

            let aboutview = self.storyboard?.instantiateViewControllerWithIdentifier("AboutViewController").view as UIView?
            aboutview?.autoresizingMask = [UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleWidth]
           // aboutview?.frame = self.swipeView.bounds
            let webview = aboutview?.viewWithTag(10) as! UIWebView
            webview.scrollView.scrollEnabled = false;
            webview.delegate = self
            let htmlfile = NSBundle.mainBundle().pathForResource("About", ofType: "html")
            let htmlString: String?
            do {
                htmlString = try String(contentsOfFile: htmlfile!, encoding: NSUTF8StringEncoding)
            } catch _ {
                htmlString = nil
            }

            webview.loadHTMLString(htmlString!, baseURL: nil)

            let chatbutton = aboutview?.viewWithTag(20) as! UIButton
            chatbutton.addTarget(self, action: #selector(AboutPagedViewController.startChat), forControlEvents: UIControlEvents.TouchUpInside
            )
            let reviewbutton = aboutview?.viewWithTag(30) as! UIButton
            reviewbutton.addTarget(self, action: #selector(AboutPagedViewController.reviewApp), forControlEvents: UIControlEvents.TouchUpInside
            )

            if let coffeeimg = aboutview?.viewWithTag(40) as? UIImageView {
                coffeeimg.userInteractionEnabled = true;

                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(AboutPagedViewController.openSettings))
                tapGesture.numberOfTapsRequired = 2
                coffeeimg.addGestureRecognizer(tapGesture)
            }

            return aboutview
        }
        var label: UILabel


        let view = UIView()
        view.autoresizingMask = [UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleWidth]

        label = UILabel(frame: view.bounds)
        label.autoresizingMask = [UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleWidth]
        label.backgroundColor = UIColor.clearColor()
        label.textAlignment = NSTextAlignment.Center;
        label.tag = 1;
        view.addSubview(label)
        view.backgroundColor = UIColor.clearColor()
        label.lineBreakMode = NSLineBreakMode.ByWordWrapping
        label.numberOfLines=0
        label.text = String("Here comes the onboarding page \(index)")
        label.font = UIFont.systemFontOfSize(30)
        label.textColor = UIColor.whiteColor()
        return view
    }

    func startChat() {
        Smooch.show()
    }

    func reviewApp() {
        if let path = NSURL(string: "itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=990987379&onlyLatestVersion=true&pageNumber=0&sortOrdering=1&type=Purple+Software") {
            UIApplication.sharedApplication().openURL(path)
        }
    }

    func openSettings() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc: UIViewController! = storyboard.instantiateViewControllerWithIdentifier("SettingsViewController") as UIViewController
        self.presentViewController(vc, animated: true, completion: nil)
    }

    func swipeViewItemSize(swipeView: SwipeView!) -> CGSize {
        return self.swipeView.bounds.size
    }

    func swipeViewDidScroll(swipeView: SwipeView!) {

        // Put it outside view, if on first screen, since
        /// that one doesn't have transparent background now
        if(swipeView.scrollOffset  == 0 )  {
            bgImageLeft.constant = swipeView.frame.width
        } else {
            bgImageLeft.constant = -(swipeView.scrollOffset * swipeView.frame.width * 0.6) - 100
        }
        self.view.layoutIfNeeded()
    }

    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        if (navigationType == UIWebViewNavigationType.LinkClicked) {
            UIApplication.sharedApplication().openURL(request.URL!)
            return false
        }
        return true
    }

    override func viewWillDisappear(animated: Bool) {
        //bgImage.hidden = true
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        swipeView.pagingEnabled = true
    }
}
