
//
//  PagedStationsViewController.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 06.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation

class PagedStationsViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIScrollViewDelegate {

    @IBOutlet weak var test: UINavigationItem!

    @IBOutlet var pageIndicator: UIPageControl!
    var pageViewController: PagedStationsViewController?
    var currentPageIndex: Int?


    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.dataSource = self
        self.delegate = self
        currentPageIndex = 0
        var startingViewController = self.storyboard?.instantiateViewControllerWithIdentifier("StationsView") as StationsViewController
        startingViewController.showFavorites = false
        startingViewController.pageIndex = 0
        self.setViewControllers([startingViewController], direction: UIPageViewControllerNavigationDirection.Forward, animated: false, completion: nil)

        var aboutButton = UIBarButtonItem(title: "☕︎", style: UIBarButtonItemStyle.Plain, target: self, action: "aboutClicked:")
        aboutButton.tintColor = UIColor.blackColor()

        let font = UIFont.systemFontOfSize(30)
        let buttonAttr = [NSFontAttributeName: font]
        aboutButton.setTitleTextAttributes(buttonAttr, forState: UIControlState.Normal)
        self.navigationItem.rightBarButtonItem = aboutButton
        

        var titleView = UIView(frame: CGRect(x: 0, y: 0, width: 250, height: 30))
        titleView.clipsToBounds = true
        titleView.backgroundColor = UIColor.redColor()
        
        var labelContainer = UIView(frame: CGRect(x: 0, y: 0, width: 500, height: 30))
        labelContainer.tag = 100
        
        var pageLabel1 = UILabel(frame: CGRect(x: 0, y: 0, width: 250, height: 30))
        pageLabel1.text = "Nearest Stations"
        pageLabel1.textAlignment = NSTextAlignment.Center
        pageLabel1.backgroundColor = UIColor.blueColor()
        
        var pageLabel2 = UILabel(frame: CGRect(x: 250, y: 0, width: 250, height: 30))
        pageLabel2.text = "Favorites"
        pageLabel2.textAlignment = NSTextAlignment.Center
        pageLabel2.backgroundColor = UIColor.greenColor()
        
        labelContainer.addSubview(pageLabel1)
        labelContainer.addSubview(pageLabel2)
        
        titleView.addSubview(labelContainer)
        
        self.navigationItem.titleView = titleView
    
        
        let pageControl = UIPageControl.appearance()
        pageControl.backgroundColor = UIColor.redColor()
        pageControl.pageIndicatorTintColor = UIColor.lightGrayColor()
        pageControl.currentPageIndicatorTintColor = UIColor.blackColor()
        
       
        
        for v in self.view.subviews {
            if v.isKindOfClass(UIScrollView){
                (v as UIScrollView).delegate = self
            }
        }
        
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        
        var realOffset = scrollView.contentOffset.x - scrollView.frame.width
        
        //self.navigationItem.titleView?.layer.position.x = scrollView.contentOffset.x
        var xPosition = self.navigationItem.titleView?.viewWithTag(100)?.layer.position.x
        self.navigationItem.titleView?.viewWithTag(100)?.layer.position.x = -(scrollView.contentOffset.x + (CGFloat(currentPageIndex!) * scrollView.frame.width))
    }
    
    


    func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
        let vc:StationsViewController = viewController as StationsViewController
        if (vc.pageIndex == 1) {
            return nil;
        }
        var newVc: StationsViewController = self.storyboard?.instantiateViewControllerWithIdentifier("StationsView") as StationsViewController
        newVc.pageIndex = 1
        newVc.showFavorites = true
        return newVc
    }

    func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
        let vc:StationsViewController = viewController as StationsViewController
        if (vc.pageIndex == 0) {
            return nil;
        }
        var newVc: StationsViewController = self.storyboard?.instantiateViewControllerWithIdentifier("StationsView") as StationsViewController
        newVc.pageIndex = 0
        newVc.showFavorites = false
        return newVc
    }
    
    func pageViewController(pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [AnyObject], transitionCompleted completed: Bool) {
        if (completed) {
            if (currentPageIndex == 0) {
                currentPageIndex = 1
            } else {
                currentPageIndex = 0
            }
        }
        println(completed)
        println(currentPageIndex)
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