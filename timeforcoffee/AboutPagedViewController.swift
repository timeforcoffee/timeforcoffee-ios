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
    @IBAction func closeButtonAction(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }

    func numberOfItems(in swipeView: SwipeView!) -> Int {
        return 1
    }

    func swipeView(_ swipeView: SwipeView!, viewForItemAt index: Int, reusing view: UIView!) -> UIView! {

        if (index == 0) {
            

            let aboutview = self.storyboard?.instantiateViewController(withIdentifier: "AboutViewController").view as UIView?
            aboutview?.autoresizingMask = [UIView.AutoresizingMask.flexibleHeight, UIView.AutoresizingMask.flexibleWidth]
           // aboutview?.frame = self.swipeView.bounds
            let webview = aboutview?.viewWithTag(10) as! UIWebView
            webview.scrollView.isScrollEnabled = false;
            webview.delegate = self
            let htmlfile = Bundle.main.path(forResource: "About", ofType: "html")
            let htmlString: String?
            do {
                htmlString = try String(contentsOfFile: htmlfile!, encoding: String.Encoding.utf8)
            } catch _ {
                htmlString = nil
            }

            webview.loadHTMLString(htmlString!, baseURL: nil)

            let chatbutton = aboutview?.viewWithTag(20) as! UIButton
            chatbutton.addTarget(self, action: #selector(AboutPagedViewController.startChat), for: UIControl.Event.touchUpInside
            )
            let reviewbutton = aboutview?.viewWithTag(30) as! UIButton
            reviewbutton.addTarget(self, action: #selector(AboutPagedViewController.reviewApp), for: UIControl.Event.touchUpInside
            )

            if let coffeeimg = aboutview?.viewWithTag(40) as? UIImageView {
                coffeeimg.isUserInteractionEnabled = true;

                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(AboutPagedViewController.openSettings))
                tapGesture.numberOfTapsRequired = 2
                coffeeimg.addGestureRecognizer(tapGesture)
            }

            return aboutview
        }
        var label: UILabel


        let view = UIView()
        view.autoresizingMask = [UIView.AutoresizingMask.flexibleHeight, UIView.AutoresizingMask.flexibleWidth]

        label = UILabel(frame: view.bounds)
        label.autoresizingMask = [UIView.AutoresizingMask.flexibleHeight, UIView.AutoresizingMask.flexibleWidth]
        label.backgroundColor = UIColor.clear
        label.textAlignment = NSTextAlignment.center;
        label.tag = 1;
        view.addSubview(label)
        view.backgroundColor = UIColor.clear
        label.lineBreakMode = NSLineBreakMode.byWordWrapping
        label.numberOfLines=0
        label.text = String("Here comes the onboarding page \(index)")
        label.font = UIFont.systemFont(ofSize: 30)
        label.textColor = UIColor.white
        return view
    }

    @objc func startChat() {
        Smooch.show()
    }

    @objc func reviewApp() {
        if let path = URL(string: "itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=990987379&onlyLatestVersion=true&pageNumber=0&sortOrdering=1&type=Purple+Software") {
            UIApplication.shared.openURL(path)
        }
    }

    @objc func openSettings() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc: UIViewController! = storyboard.instantiateViewController(withIdentifier: "SettingsViewController") as UIViewController
        self.present(vc, animated: true, completion: nil)
    }

    func swipeViewItemSize(_ swipeView: SwipeView!) -> CGSize {
        return self.swipeView.bounds.size
    }

    func swipeViewDidScroll(_ swipeView: SwipeView!) {

        // Put it outside view, if on first screen, since
        /// that one doesn't have transparent background now
        if(swipeView.scrollOffset  == 0 )  {
            bgImageLeft.constant = swipeView.frame.width
        } else {
            bgImageLeft.constant = -(swipeView.scrollOffset * swipeView.frame.width * 0.6) - 100
        }
        self.view.layoutIfNeeded()
    }

    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebView.NavigationType) -> Bool {
        if (navigationType == UIWebView.NavigationType.linkClicked) {
            UIApplication.shared.openURL(request.url!)
            return false
        }
        return true
    }

    override func viewWillDisappear(_ animated: Bool) {
        //bgImage.hidden = true
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        swipeView.isPagingEnabled = true
    }
}
