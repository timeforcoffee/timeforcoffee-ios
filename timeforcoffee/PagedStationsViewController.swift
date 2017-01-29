
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
        let view = self.storyboard?.instantiateViewController(withIdentifier: "StationsView") as! StationsViewController
        view.showFavorites = false
        view.pageIndex = 0
        return view
    }()

    lazy var favoritesView: StationsViewController = {
        let newVc: StationsViewController = self.storyboard?.instantiateViewController(withIdentifier: "StationsView") as! StationsViewController
        newVc.pageIndex = 1
        newVc.showFavorites = true
        return newVc
    }()

     fileprivate lazy var locManager: TFCLocationManager? = { return TFCLocationManager(delegate: self)}()

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.dataSource = self
        self.delegate = self
        moveToNearbyStations()

        let aboutButton = UIBarButtonItem(title: "☕︎", style: UIBarButtonItemStyle.plain, target: self, action: #selector(PagedStationsViewController.aboutClicked(_:)))
        aboutButton.image = UIImage(named: "icon-coffee")
        aboutButton.tintColor = UIColor(netHexString: "555555")
        aboutButton.accessibilityLabel = NSLocalizedString("About", comment: "")
        aboutButton.accessibilityHint = NSLocalizedString("Help and chat with us", comment: "")

        let font = UIFont.systemFont(ofSize: 30)
        let buttonAttr = [NSFontAttributeName: font]
        aboutButton.setTitleTextAttributes(buttonAttr, for: UIControlState())
        self.navigationItem.leftBarButtonItem = aboutButton
        self.edgesForExtendedLayout = UIRectEdge();

        setSearchButton()
        setTitleView()
        
        for v in self.view.subviews {
            if v.isKind(of: UIScrollView.self){
                scrollView = (v as! UIScrollView)
                scrollView?.delegate = self
            }
        }
        if (scrollView != nil) {
            scrollViewDidScroll(scrollView!)
        }

    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshLocation()
    }

    override func viewDidAppear(_ animated: Bool) {
        if (!registeredObserver) {
            NotificationCenter.default.addObserver(self, selector: #selector(UIApplicationDelegate.applicationDidBecomeActive(_:)), name: NSNotification.Name(rawValue: "UIApplicationDidBecomeActiveNotification"), object: nil)
            registeredObserver = true
        }
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
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

    internal func locationDenied(_ manager: CLLocationManager, err: Error) {
        moveToFavorites()
    }
    internal func locationFixed(_ coord: CLLocation?) {
        moveToFavorites()
    }

    internal func locationStillTrying(_ manager: CLLocationManager, err: Error) {

    }

    fileprivate func refreshLocation() {
        if (self.searchController == nil) {
            let currentView: StationsViewController  = self.viewControllers!.first as! StationsViewController
            currentView.appsTableView?.refreshLocation()
        }
    }

    fileprivate func setTitleView () {
        scrollViewWidth = UIScreen.main.bounds.size.width
        
        let titleView = UIView(frame: CGRect(x: 0, y: 0, width: scrollViewWidth! / 2, height: 30))

        let labelContainer = UIView(frame: CGRect(x: 0, y: 0, width: (scrollViewWidth! / 2) * 2, height: 20))
        labelContainer.tag = 100
        
        
        let labelFont = UIFont(name: "HelveticaNeue-Bold", size: 14.0)

        let pageLabel1 = UILabel(frame: CGRect(x: 0, y: 0, width: scrollViewWidth! / 2, height: 20))
        pageLabel1.text = NSLocalizedString("Nearby Stations", comment: "")
        pageLabel1.font = labelFont
        pageLabel1.textAlignment = NSTextAlignment.center
        pageLabel1.tag = 1

        let pageLabel2 = UILabel(frame: CGRect(x: scrollViewWidth! / 2, y: 0, width: scrollViewWidth! / 2, height: 20))
        pageLabel2.text = NSLocalizedString("Favourites", comment: "")
        pageLabel2.font = labelFont
        pageLabel2.textAlignment = NSTextAlignment.center
        pageLabel2.tag = 2
        

        labelContainer.addSubview(pageLabel1)
        labelContainer.addSubview(pageLabel2)

        titleView.addSubview(labelContainer)
        let titlePageControl = UIPageControl(frame: CGRect(x: 0, y: 20, width: scrollViewWidth! / 2, height: 10))
        titlePageControl.tag = 50
        titlePageControl.numberOfPages = 2
        titlePageControl.currentPage = 0
        titlePageControl.currentPageIndicatorTintColor = UIColor.black
        titlePageControl.pageIndicatorTintColor = UIColor.gray
        titlePageControl.transform = titlePageControl.transform.scaledBy(x: 0.75, y: 0.75)
        titlePageControl.isUserInteractionEnabled = false
        titlePageControl.isAccessibilityElement = false
        titleView.addSubview(titlePageControl)


        self.navigationItem.titleView = titleView

        self.navigationItem.titleView?.layer.frame = CGRect(x: 0, y: 0, width: scrollViewWidth! / 2, height: 30)
        self.navigationItem.titleView?.clipsToBounds = false
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (currentPageIndex == 0) {
            scrollViewOffset = scrollView.contentOffset.x - scrollView.frame.width
            if let scrollViewWidth = self.scrollViewWidth {
                self.navigationItem.titleView?.viewWithTag(1)?.layer.opacity = 1 - Float(((scrollView.contentOffset.x - scrollViewWidth) / scrollViewWidth))
                self.navigationItem.titleView?.viewWithTag(2)?.layer.opacity = Float(((scrollView.contentOffset.x - scrollViewWidth) / scrollViewWidth))
            }
        } else {
            scrollViewOffset = scrollView.contentOffset.x
            if let scrollViewWidth = scrollViewWidth {
                self.navigationItem.titleView?.viewWithTag(1)?.layer.opacity = -Float(((scrollView.contentOffset.x - scrollViewWidth) / scrollViewWidth))
                self.navigationItem.titleView?.viewWithTag(2)?.layer.opacity = 1 + Float(((scrollView.contentOffset.x - scrollViewWidth) / scrollViewWidth))
            }
        }
        self.navigationItem.titleView?.viewWithTag(100)?.layer.position.x = (-scrollViewOffset! / 2) + scrollViewWidth! / 2
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        let vc:StationsViewController = viewController as! StationsViewController
        if (vc.pageIndex == 1) {
            return nil;
        }
        return favoritesView
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        let vc:StationsViewController = viewController as! StationsViewController
        if (vc.pageIndex == 0) {
            return nil;
        }
        return nearbyStationsView
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if (completed == true && finished == true) {
            if let currentViewController = pageViewController.viewControllers?.first as? StationsViewController {
                if (currentViewController.pageIndex != currentPageIndex) {
                    setPageControlDot()
                }
            }
  //          let currentView: StationsViewController  = pageViewController.viewControllers!.first as! StationsViewController
        }
    }

    fileprivate func setPageControlDot() {
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

    func moveTo(_ view: StationsViewController) {

        self.setViewControllers( [view], direction: UIPageViewControllerNavigationDirection.forward, animated: false, completion: {(finished:Bool) -> Void in

            }
        )
        currentPageIndex = view.pageIndex
        if (self.scrollView != nil) {
            scrollViewDidScroll(self.scrollView!)
        }
        setPageControlDot()
    }

    fileprivate func getCurrentView() -> StationsViewController {
        return self.viewControllers?.first as! StationsViewController
    }

    fileprivate func setSearchButton() {
        let searchButton = UIBarButtonItem(title: "", style: UIBarButtonItemStyle.plain, target: self, action: #selector(PagedStationsViewController.searchClicked(_:)))

        searchButton.image = UIImage(named: "icon-search")
        searchButton.tintColor = UIColor(netHexString: "555555")
        searchButton.accessibilityLabel = NSLocalizedString("Search", comment: "")
        searchButton.accessibilityHint = NSLocalizedString("for Stations", comment: "")
        self.navigationItem.rightBarButtonItem = searchButton
    }
    
    func searchClicked(_ sender: UIBarButtonItem) {
        searchClicked()
    }

    func searchClicked() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let ssv: StationsSearchViewController = storyboard.instantiateViewController(withIdentifier: "StationsSearchView") as! StationsSearchViewController;

        self.navigationController?.pushViewController(ssv, animated: false)
    }

    func aboutClicked(_ sender: UIBarButtonItem) {
        /* #if DEBUG
        TFCFavorites.sharedInstance.repopulateFavorites()
        let favs = Array(TFCFavorites.sharedInstance.stations.values)
        let randomIndex = Int(arc4random_uniform(UInt32(favs.count)))

        let station = favs[randomIndex]
        TFCDataStore.sharedInstance.sendComplicationUpdate(station, coord: station.coord?.coordinate)

        return
        #endif */
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc: UIViewController! = storyboard.instantiateViewController(withIdentifier: "AboutPagedViewController") as UIViewController
        self.navigationController?.present(vc, animated: true, completion: nil)

    }
}
