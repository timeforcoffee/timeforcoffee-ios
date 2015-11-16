
//
//  PagedStationsViewController.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 06.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import UIKit
import timeforcoffeeKit
import CoreLocation

final class PagedStationsViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIScrollViewDelegate, TFCLocationManagerDelegate {

    @IBOutlet weak var test: UINavigationItem!

    //@IBOutlet var pageIndicator: UIPageControl!
    var currentPageIndex: Int?
    var scrollViewOffset: CGFloat? = 0
    var scrollViewWidth: CGFloat?
    var searchController: UISearchController?
    var scrollView: UIScrollView?
    var registeredObserver: Bool = false
    lazy var nearbyStationsView: StationsViewController = {
        let view = self.storyboard?.instantiateViewControllerWithIdentifier("StationsView") as! StationsViewController
        view.showFavorites = false
        view.pageIndex = 0
        return view
    }()

    lazy var favoritesView: StationsViewController = {
        let newVc: StationsViewController = self.storyboard?.instantiateViewControllerWithIdentifier("StationsView") as! StationsViewController
        newVc.pageIndex = 1
        newVc.showFavorites = true
        return newVc
    }()

     private lazy var locManager: TFCLocationManager? = { return TFCLocationManager(delegate: self)}()

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.dataSource = self
        self.delegate = self
        moveToNearbyStations()

        let aboutButton = UIBarButtonItem(title: "☕︎", style: UIBarButtonItemStyle.Plain, target: self, action: "aboutClicked:")
        aboutButton.image = UIImage(named: "icon-coffee")
        aboutButton.tintColor = UIColor(netHexString: "555555")
        let font = UIFont.systemFontOfSize(30)
        let buttonAttr = [NSFontAttributeName: font]
        aboutButton.setTitleTextAttributes(buttonAttr, forState: UIControlState.Normal)
        self.navigationItem.leftBarButtonItem = aboutButton
        self.edgesForExtendedLayout = UIRectEdge.None;

        setSearchButton()
        setTitleView()
        
        for v in self.view.subviews {
            if v.isKindOfClass(UIScrollView){
                scrollView = (v as! UIScrollView)
                scrollView?.delegate = self
            }
        }
        if (scrollView != nil) {
            scrollViewDidScroll(scrollView!)
        }

    }
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func applicationDidBecomeActive(notification: NSNotification) {
        refreshLocation()
    }

    override func viewDidAppear(animated: Bool) {
        if (!registeredObserver) {
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBecomeActive:", name: "UIApplicationDidBecomeActiveNotification", object: nil)
            registeredObserver = true
        }
        showOnBoardingOrRefreshLocation()
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        if (appDelegate.startedWithShortcut == "ch.opendata.timeforcoffee.favorites") {
            // wait somehow until we have a location....
            if (locManager!.currentLocation != nil) {
                moveToFavorites()
                appDelegate.startedWithShortcut = nil
            } else {
                locManager!.refreshLocation()
            }
        } else {
            refreshLocation()
        }
    }

    internal func locationDenied(manager: CLLocationManager, err: NSError) {
        moveToFavorites()
    }
    internal func locationFixed(coord: CLLocation?) {
        moveToFavorites()
    }

    internal func locationStillTrying(manager: CLLocationManager, err: NSError) {

    }

    private func refreshLocation() {
        if (self.searchController == nil) {
            let currentView: StationsViewController  = self.viewControllers!.first as! StationsViewController
            currentView.appsTableView?.refreshLocation()
        }
    }

    private func showOnBoardingOrRefreshLocation() {

        if (TFCDataStore.sharedInstance.getUserDefaults()?.boolForKey("onboardingShown") != true) {

            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc: AboutPagedViewController! = storyboard.instantiateViewControllerWithIdentifier("AboutPagedViewController") as! AboutPagedViewController
            self.navigationController?.presentViewController(vc, animated: true, completion: nil)
        } else {
            refreshLocation()
        }
    }

    private func setTitleView () {
        scrollViewWidth = UIScreen.mainScreen().bounds.size.width
        
        let titleView = UIView(frame: CGRect(x: 0, y: 0, width: scrollViewWidth! / 2, height: 30))

        let labelContainer = UIView(frame: CGRect(x: 0, y: 0, width: (scrollViewWidth! / 2) * 2, height: 20))
        labelContainer.tag = 100
        
        
        let labelFont = UIFont(name: "HelveticaNeue-Bold", size: 14.0)

        let pageLabel1 = UILabel(frame: CGRect(x: 0, y: 0, width: scrollViewWidth! / 2, height: 20))
        pageLabel1.text = NSLocalizedString("Nearby Stations", comment: "")
        pageLabel1.font = labelFont
        pageLabel1.textAlignment = NSTextAlignment.Center
        pageLabel1.tag = 1

        let pageLabel2 = UILabel(frame: CGRect(x: scrollViewWidth! / 2, y: 0, width: scrollViewWidth! / 2, height: 20))
        pageLabel2.text = NSLocalizedString("Favourites", comment: "")
        pageLabel2.font = labelFont
        pageLabel2.textAlignment = NSTextAlignment.Center
        pageLabel2.tag = 2
        

        labelContainer.addSubview(pageLabel1)
        labelContainer.addSubview(pageLabel2)

        titleView.addSubview(labelContainer)
        let titlePageControl = UIPageControl(frame: CGRect(x: 0, y: 20, width: scrollViewWidth! / 2, height: 10))
        titlePageControl.tag = 50
        titlePageControl.numberOfPages = 2
        titlePageControl.currentPage = 0
        titlePageControl.currentPageIndicatorTintColor = UIColor.blackColor()
        titlePageControl.pageIndicatorTintColor = UIColor.grayColor()
        titlePageControl.transform = CGAffineTransformScale(titlePageControl.transform, 0.75, 0.75)
        titlePageControl.userInteractionEnabled = false
        titleView.addSubview(titlePageControl)
        

        self.navigationItem.titleView = titleView

        self.navigationItem.titleView?.layer.frame = CGRect(x: 0, y: 0, width: scrollViewWidth! / 2, height: 30)
        self.navigationItem.titleView?.clipsToBounds = false
    }

    func scrollViewDidScroll(scrollView: UIScrollView) {
        if (currentPageIndex == 0) {
            scrollViewOffset = scrollView.contentOffset.x - scrollView.frame.width
            self.navigationItem.titleView?.viewWithTag(1)?.layer.opacity = 1 - Float(((scrollView.contentOffset.x - scrollViewWidth!) / scrollViewWidth!))
            self.navigationItem.titleView?.viewWithTag(2)?.layer.opacity = Float(((scrollView.contentOffset.x - scrollViewWidth!) / scrollViewWidth!))
        } else {
            scrollViewOffset = scrollView.contentOffset.x
            self.navigationItem.titleView?.viewWithTag(1)?.layer.opacity = -Float(((scrollView.contentOffset.x - scrollViewWidth!) / scrollViewWidth!))
            self.navigationItem.titleView?.viewWithTag(2)?.layer.opacity = 1 + Float(((scrollView.contentOffset.x - scrollViewWidth!) / scrollViewWidth!))
        }
        self.navigationItem.titleView?.viewWithTag(100)?.layer.position.x = (-scrollViewOffset! / 2) + scrollViewWidth! / 2
    }

    func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
        let vc:StationsViewController = viewController as! StationsViewController
        if (vc.pageIndex == 1) {
            return nil;
        }
        return favoritesView
    }

    func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
        let vc:StationsViewController = viewController as! StationsViewController
        if (vc.pageIndex == 0) {
            return nil;
        }
        return nearbyStationsView
    }
    
    func pageViewController(pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if (completed == true && finished == true) {
            if let currentViewController = pageViewController.viewControllers?.first as? StationsViewController {
                if (currentViewController.pageIndex != currentPageIndex) {
                    setPageControlDot()
                }
            }
  //          let currentView: StationsViewController  = pageViewController.viewControllers!.first as! StationsViewController
        }
    }

    private func setPageControlDot() {
        let currentViewController = getCurrentView()
        currentPageIndex = currentViewController.pageIndex
        let pc: UIPageControl? = self.navigationItem.titleView?.viewWithTag(50) as! UIPageControl?
        if (pc != nil) {
            pc?.currentPage = currentPageIndex!
        }
    }

    func moveToNearbyStations() {
        moveTo(nearbyStationsView)
    }

    func moveToFavorites() {
        moveTo(favoritesView)
    }

    func moveTo(view: StationsViewController) {

        self.setViewControllers( [view], direction: UIPageViewControllerNavigationDirection.Forward, animated: false, completion: {(finished:Bool) -> Void in

            }
        )
        currentPageIndex = view.pageIndex
        if (self.scrollView != nil) {
            scrollViewDidScroll(self.scrollView!)
        }
        setPageControlDot()
    }

    private func getCurrentView() -> StationsViewController {
        return self.viewControllers?.first as! StationsViewController
    }

    private func setSearchButton() {
        let searchButton = UIBarButtonItem(title: "", style: UIBarButtonItemStyle.Plain, target: self, action: "searchClicked:")

        searchButton.image = UIImage(named: "icon-search")
        searchButton.tintColor = UIColor(netHexString: "555555")

        self.navigationItem.rightBarButtonItem = searchButton
    }
    
    func searchClicked(sender: UIBarButtonItem) {
        searchClicked()
    }

    func searchClicked() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let ssv: StationsSearchViewController = storyboard.instantiateViewControllerWithIdentifier("StationsSearchView") as! StationsSearchViewController;

        self.navigationController?.pushViewController(ssv, animated: false)
    }

    func aboutClicked(sender: UIBarButtonItem) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc: UIViewController! = storyboard.instantiateViewControllerWithIdentifier("AboutPagedViewController") as UIViewController
        self.navigationController?.presentViewController(vc, animated: true, completion: nil)

    }
}