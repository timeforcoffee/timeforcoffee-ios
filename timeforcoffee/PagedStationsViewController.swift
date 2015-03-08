
//
//  PagedStationsViewController.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 06.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation

class PagedStationsViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIScrollViewDelegate, UISearchBarDelegate {

    @IBOutlet weak var test: UINavigationItem!

    @IBOutlet var pageIndicator: UIPageControl!
    var pageViewController: PagedStationsViewController?
    var currentPageIndex: Int?
    var scrollViewOffset: CGFloat? = 0
    var searchController: UISearchController?


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
        self.navigationItem.leftBarButtonItem = aboutButton

        setSearchButton()
        setTitleView()

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

    func setTitleView () {
        var titleView = UIView(frame: CGRect(x: 0, y: 0, width: 160, height: 30))

        var labelContainer = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 30))
        labelContainer.tag = 100

        var pageLabel1 = UILabel(frame: CGRect(x: 0, y: 0, width: 160, height: 30))
        pageLabel1.text = "Nearest Stations"
        pageLabel1.textAlignment = NSTextAlignment.Center
        pageLabel1.tag = 1

        var pageLabel2 = UILabel(frame: CGRect(x: 160, y: 0, width: 160, height: 30))
        pageLabel2.text = "Favorites"
        pageLabel2.textAlignment = NSTextAlignment.Center
        pageLabel2.tag = 2

        labelContainer.addSubview(pageLabel1)
        labelContainer.addSubview(pageLabel2)

        titleView.addSubview(labelContainer)

        self.navigationItem.titleView = titleView

        self.navigationItem.titleView?.layer.frame = CGRect(x: 0, y: 0, width: 160, height: 30)
        self.navigationItem.titleView?.clipsToBounds = false
    }

    func scrollViewDidScroll(scrollView: UIScrollView) {
        if (currentPageIndex == 0) {
            scrollViewOffset = scrollView.contentOffset.x - scrollView.frame.width
        } else {
            scrollViewOffset = scrollView.contentOffset.x
        }
        self.navigationItem.titleView?.viewWithTag(100)?.layer.position.x = (-scrollViewOffset! / 2) + 160
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
        if (completed == true && finished == true) {
            if let currentViewController = pageViewController.viewControllers?.first as? StationsViewController {
                if (currentViewController.pageIndex != currentPageIndex) {
                    currentPageIndex = currentViewController.pageIndex
                }
            }
            let currentView: StationsViewController  = pageViewController.viewControllers[0] as StationsViewController
            currentView.appsTableView?.refreshLocation()
        }
    }

    func setSearchButton() {
        var searchButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Search, target: self, action: "searchClicked:")
        self.navigationItem.rightBarButtonItem = searchButton
    }
    
    func searchClicked(sender: UIBarButtonItem) {
        let sc: UISearchController = UISearchController(searchResultsController: nil)
        let searchBarFrame: CGRect = sc.searchBar.frame
        var newframe = CGRectMake(searchBarFrame.origin.x,
            searchBarFrame.origin.y,
            searchBarFrame.size.width,
            55);
        sc.searchBar.frame = newframe

        self.searchController = sc
        self.searchController?.hidesNavigationBarDuringPresentation = false;
        self.searchController?.dimsBackgroundDuringPresentation = false;
        self.definesPresentationContext = true;
        let searchBar = self.searchController?.searchBar
        self.navigationItem.rightBarButtonItem = nil;

        self.navigationItem.titleView = searchBar
        searchBar?.alpha = 0.0;
        searchBar?.delegate = self
        var delay: NSTimeInterval = 0.5
        UIView.animateWithDuration(delay,
            animations: {
                //searchBar?.alpha = CGFloat(1.0)
                searchBar?.alpha = 1.0
                return
            }, completion: { (finished:Bool) in
                searchBar?.becomeFirstResponder()
                return
        })
        self.presentViewController(self.searchController!, animated: true, completion: nil)
    }

    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        var searchBar = self.searchController?.searchBar
        UIView.animateWithDuration(NSTimeInterval(0.5), animations: {
                searchBar?.alpha = 0.0
                return
            }, completion: { (finished:Bool) in
                self.navigationItem.titleView = nil;
                self.navigationItem.rightBarButtonItem = nil;
                self.setTitleView()
                self.setSearchButton()
                return
        })
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