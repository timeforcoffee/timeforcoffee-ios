
//
//  PagedStationsViewController.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 06.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation

class PagedStationsViewController: UIPageViewController, UIPageViewControllerDataSource {


    @IBOutlet var pageIndicator: UIPageControl!
    var pageViewController: PagedStationsViewController?;


    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.dataSource = self
        var startingViewController = self.storyboard?.instantiateViewControllerWithIdentifier("StationsView") as SearchResultsViewController
        startingViewController.showFavorites = false
        startingViewController.pageIndex = 0
        self.setViewControllers([startingViewController], direction: UIPageViewControllerNavigationDirection.Forward, animated: false, completion: nil)

        var aboutButton = UIBarButtonItem(title: "☕︎", style: UIBarButtonItemStyle.Plain, target: self, action: "aboutClicked:")
        aboutButton.tintColor = UIColor.blackColor()

        let font = UIFont.systemFontOfSize(30)
        let buttonAttr = [NSFontAttributeName: font]
        aboutButton.setTitleTextAttributes(buttonAttr, forState: UIControlState.Normal)
        self.navigationItem.rightBarButtonItem = aboutButton

        let pageControl = UIPageControl.appearance()
        pageControl.backgroundColor = UIColor.whiteColor()
        pageControl.pageIndicatorTintColor = UIColor.lightGrayColor()
       pageControl.currentPageIndicatorTintColor = UIColor.blackColor()
    }

    func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {

        let vc:SearchResultsViewController = viewController as SearchResultsViewController
        if (vc.pageIndex == 1) {
            return nil;
        }
        var newVc: SearchResultsViewController = self.storyboard?.instantiateViewControllerWithIdentifier("StationsView") as SearchResultsViewController
        newVc.pageIndex = 1
        newVc.showFavorites = true
        return newVc
    }

    func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
        let vc:SearchResultsViewController = viewController as SearchResultsViewController
        if (vc.pageIndex == 0) {
            return nil;
        }
        var newVc: SearchResultsViewController = self.storyboard?.instantiateViewControllerWithIdentifier("StationsView") as SearchResultsViewController
        newVc.pageIndex = 0
        newVc.showFavorites = false
        return newVc
    }

    func aboutClicked(sender: UIBarButtonItem) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc: UIViewController! = storyboard.instantiateViewControllerWithIdentifier("AboutViewController") as UIViewController
        self.navigationController?.pushViewController(vc, animated: true)
    }
    func presentationCountForPageViewController(pageViewController: UIPageViewController) -> Int {
        return 2
    }
    func presentationIndexForPageViewController(pageViewController: UIPageViewController) -> Int {
        return 0
    }

}