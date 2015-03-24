//
//  AboutPaged.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 24.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import SwipeView

class AboutPagedViewController: UIViewController, SwipeViewDataSource, SwipeViewDelegate {

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


    override func viewDidLoad() {
        println ("viewdidload"  )
        super.viewDidLoad()
        swipeView.pagingEnabled = true
    }
}