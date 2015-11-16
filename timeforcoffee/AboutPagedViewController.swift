//
//  AboutPaged.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 24.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import SwipeView
import timeforcoffeeKit
import CoreLocation

final class AboutPagedViewController: UIViewController, SwipeViewDataSource, SwipeViewDelegate, UIWebViewDelegate, CLLocationManagerDelegate {

    @IBOutlet weak var swipeView: SwipeView!

    @IBOutlet weak var bgImage: UIImageView!

    @IBOutlet weak var bgImageLeft: NSLayoutConstraint!
    @IBAction func closeButtonAction(sender: AnyObject) {
        TFCDataStore.sharedInstance.getUserDefaults()?.setBool(true, forKey: "onboardingShown")
        self.dismissViewControllerAnimated(true, completion: nil)


    }
    var lm: CLLocationManager?
    lazy var onBoardingShown:Bool = {
        if (TFCDataStore.sharedInstance.getUserDefaults()?.boolForKey("onboardingShown") == true) {
            return true
        } else {
            return false
        }
    }()


    func numberOfItemsInSwipeView(swipeView: SwipeView!) -> Int {
        if (onBoardingShown) {
            return 2
        }

        return 4
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
            chatbutton.addTarget(self, action: "startChat", forControlEvents: UIControlEvents.TouchUpInside
            )

            if let coffeeimg = aboutview?.viewWithTag(40) as? UIImageView {
                coffeeimg.userInteractionEnabled = true;

                let tapGesture = UITapGestureRecognizer(target: self, action: "openSettings")
                tapGesture.numberOfTapsRequired = 2
                coffeeimg.addGestureRecognizer(tapGesture)
            }

            return aboutview
        }

        let boardview = self.storyboard?.instantiateViewControllerWithIdentifier("OnBoardingViewController").view as UIView?


        boardview?.autoresizingMask = UIViewAutoresizing.FlexibleHeight | UIViewAutoresizing.FlexibleWidth


        let label = boardview?.viewWithTag(1) as! UITextView


        var myIndex = index
        if (!onBoardingShown) {
            var status: CLAuthorizationStatus?
            if (CLLocationManager.locationServicesEnabled()) {
                status = CLLocationManager.authorizationStatus()
            }
            if (status == CLAuthorizationStatus.AuthorizedAlways ||
                status == CLAuthorizationStatus.AuthorizedWhenInUse) {
                    myIndex = index + 2
            }

            if (myIndex == 1) {
                if (status == CLAuthorizationStatus.Denied) {
                    label.text = "You denied location permission, please go to settings and enable it"
                } else {
                    label.text = String("First we ask you for location permission, please click 'Allow'")
                }
            }
            if (myIndex == 2) {
                label.text = String("Do it!")
            }
        } else {
            myIndex = index + 2
        }

        if (myIndex == 3) {
            label.text = String("And now some cool features...")
        }

 /*       CGSize sizeThatShouldFitTheContent = [_textView sizeThatFits:_textView.frame.size];
        heightConstraint.constant = sizeThatShouldFitTheContent.height;
*/
        return boardview
    }

    func swipeViewDidEndDecelerating(swipeView: SwipeView!) {
        if (swipeView.currentPage == 2) {
            lm = CLLocationManager()
            lm?.delegate = self
            lm?.requestAlwaysAuthorization()
        }
    }

    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {

        var shouldIAllow = false
        var locationStatus: String?
        switch status {
        case CLAuthorizationStatus.Restricted:
            locationStatus = "Restricted Access to location"
        case CLAuthorizationStatus.Denied:
            locationStatus = "User denied access to location"
        case CLAuthorizationStatus.NotDetermined:
            locationStatus = "Status not determined yet"
            return
        default:
            locationStatus = "Allowed to location Access"
            shouldIAllow = true
        }
        let label = swipeView?.viewWithTag(1) as! UITextView

        if (shouldIAllow == true) {
            label.text = "Thank you"
            TFCDataStore.sharedInstance.getUserDefaults()?.setBool(true, forKey: "onboardingShown")
        } else {
            label.text = "Ugh, that didn't work"
        }

    }

    func startChat() {
        SupportKit.show()
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


    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if (TFCDataStore.sharedInstance.getUserDefaults()?.boolForKey("onboardingShown") != true) {
            swipeView.scrollToPage(1, duration: 1.0)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        swipeView.pagingEnabled = true
    }
}