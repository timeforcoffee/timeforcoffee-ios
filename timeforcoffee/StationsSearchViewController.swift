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
        self.searchController?.hidesNavigationBarDuringPresentation = false
        self.searchController?.obscuresBackgroundDuringPresentation = false
        let searchBar = self.searchController?.searchBar

        self.navigationController?.navigationBar.tintColor = UIColor(named: "TFCGrayerColor")
        self.navigationItem.rightBarButtonItem = nil

        // Use modern search controller placement (iOS 11+)
        self.navigationItem.searchController = sc
        self.navigationItem.hidesSearchBarWhenScrolling = false

        searchBar?.delegate = self
        let appsTableView = self.appsTableView2
        appsTableView?.searchBar = searchBar
        sc.searchResultsUpdater = appsTableView
        definesPresentationContext = true
        appsTableView?.removePullToRefresh()


    }

    deinit {
        self.searchController?.isActive = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.edgesForExtendedLayout = [];

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated, noReload: true)
        // Activate search bar and show keyboard
        DispatchQueue.main.async {
            self.searchController?.isActive = true
            self.searchController?.searchBar.becomeFirstResponder()
        }
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
