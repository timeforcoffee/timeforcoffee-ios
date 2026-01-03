//
//  AboutPaged.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 24.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import SwipeView
import WebKit

final class AboutPagedViewController: UIViewController, SwipeViewDataSource, SwipeViewDelegate, WKNavigationDelegate {

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

            // Replace UIWebView container (tag 10) with WKWebView
            if let containerView = aboutview?.viewWithTag(10) {
                let webview = WKWebView(frame: containerView.bounds)
                webview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                webview.scrollView.isScrollEnabled = false
                webview.isOpaque = false
                webview.backgroundColor = .clear
                webview.scrollView.backgroundColor = .clear
                webview.navigationDelegate = self

                containerView.addSubview(webview)

                if let htmlfile = Bundle.main.path(forResource: "About", ofType: "html"),
                   let htmlString = try? String(contentsOfFile: htmlfile, encoding: .utf8) {
                    webview.loadHTMLString(htmlString, baseURL: nil)
                }
            }

            let chatbutton = aboutview?.viewWithTag(20) as! UIButton
            chatbutton.addTarget(self, action: #selector(AboutPagedViewController.startChat), for: UIControl.Event.touchUpInside
            )
            let reviewbutton = aboutview?.viewWithTag(30) as! UIButton
            reviewbutton.addTarget(self, action: #selector(AboutPagedViewController.reviewApp), for: UIControl.Event.touchUpInside
            )
            let settingsbutton = aboutview?.viewWithTag(50) as! UIButton
            settingsbutton.addTarget(self, action: #selector(AboutPagedViewController.openSettings), for: UIControl.Event.touchUpInside
            )

            let faqbutton = aboutview?.viewWithTag(60) as! UIButton
            faqbutton.addTarget(self, action: #selector(AboutPagedViewController.openFaq), for: UIControl.Event.touchUpInside
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
        let alert = UIAlertController(
            title: NSLocalizedString("Contact Us", comment: ""),
            message: NSLocalizedString("You can contact us via email at me@chregu.tv", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("Send Email", comment: ""), style: .default) { _ in
            if let url = URL(string: "mailto:me@chregu.tv?subject=Time%20for%20Coffee%20Feedback") {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        self.present(alert, animated: true)
    }

    @objc func reviewApp() {
        if let url = URL(string: "itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=990987379&onlyLatestVersion=true&pageNumber=0&sortOrdering=1&type=Purple+Software") {
            UIApplication.shared.open(url)
        }
    }

    @objc func openSettings() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc: UIViewController! = storyboard.instantiateViewController(withIdentifier: "SettingsViewController") as UIViewController
        self.present(vc, animated: true, completion: nil)
    }

    @objc func openFaq() {
        if let url = URL(string: NSLocalizedString("http://liip.to/tfc_faq", comment: "link to faq")) {
            UIApplication.shared.open(url)
        }
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

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    override func viewWillDisappear(_ animated: Bool) {
        //bgImage.hidden = true
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        swipeView.isPagingEnabled = true
    }
}
