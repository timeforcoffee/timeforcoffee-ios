//
//  StationsSearchViewController.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 10.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import UIKit

final class StationsSearchViewController: StationsViewController, UISearchBarDelegate {

    @IBOutlet weak  var appsTableView2: StationTableView?
    var searchController: UISearchController?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.hidesBackButton = false;
        let sc: UISearchController = UISearchController(searchResultsController: nil)

        self.searchController = sc
        self.searchController?.hidesNavigationBarDuringPresentation = false;
        self.searchController?.dimsBackgroundDuringPresentation = false;
        let searchBar = self.searchController?.searchBar
        
        self.navigationController?.navigationBar.tintColor = UIColor(named: "TFCGrayerColor")
        self.navigationItem.rightBarButtonItem = nil;
        self.navigationItem.titleView = searchBar

        searchBar?.delegate = self
        let appsTableView = self.appsTableView2
        appsTableView?.searchBar = searchBar
        sc.searchResultsUpdater = appsTableView
        definesPresentationContext = false
        self.view.alpha = 0.0
        appsTableView?.removePullToRefresh()
        self.searchController?.searchBar.alpha = 0.0


    }

    deinit {
        self.searchController?.dismiss(animated: false, completion: { () -> Void in

        })
        self.searchController?.removeFromParent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.edgesForExtendedLayout = [];

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated, noReload: true)
        if (!(self.searchController?.isViewLoaded == true && self.searchController?.view.window != nil)) {
            self.present(self.searchController!, animated: true, completion: {
                self.searchController?.searchBar.becomeFirstResponder()
                return
            })
        }

        let duration: TimeInterval = 0.5
        UIView.animate(withDuration: duration,
            animations: {
                self.view.alpha = 1.0
                self.searchController?.searchBar.alpha = 1.0
                return
            }, completion: { (finished:Bool) in
                return
        })
        GATracker.sharedInstance?.sendScreenName("search")
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.searchController?.searchBar.resignFirstResponder()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let detailsViewController: DeparturesViewController = segue.destination as! DeparturesViewController

        if (self.searchController != nil) {
            self.searchController?.searchBar.resignFirstResponder()
        }
        let index = appsTableView2?.indexPathForSelectedRow?.row
        if (index != nil) {
            let station = appsTableView2?.stations.getStation(index!)
            detailsViewController.setStation(station: station!);
        }
    }
}
