//
//  ViewController.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import UIKit
import MapKit
import timeforcoffeeKit

class StationsViewController: TFCBaseViewController {
    @IBOutlet weak var appsTableView : StationTableView?
    let cellIdentifier: String = "StationTableViewCell"
    var networkErrorMsg: String? = nil
    var showFavorites: Bool = false
    var pageIndex: Int?


    override func viewDidLoad() {
        super.viewDidLoad()
        definesPresentationContext = false
        appsTableView?.delegate = appsTableView
        appsTableView?.dataSource = appsTableView
        appsTableView?.showFavorites = showFavorites
        appsTableView?.stationsViewController = self
        appsTableView?.register(UINib(nibName: "StationTableViewCell", bundle: nil), forCellReuseIdentifier: "StationTableViewCell")
        appsTableView?.rowHeight = 60
        appsTableView?.backgroundView = nil
        appsTableView?.backgroundColor = UIColor(named: "TFCBackgroundColor")
        appsTableView?.refreshControl2?.backgroundColor = UIColor(named: "TFCBackgroundColor")
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func viewDidAppear(_ animated: Bool, noReload: Bool) {
        super.viewDidAppear(animated)
        if (noReload == false) {
            appsTableView?.refreshLocation()
        }

    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if (self.showFavorites) {
            GATracker.sharedInstance?.sendScreenName("favorites")
        } else {
            GATracker.sharedInstance?.sendScreenName("stations")
        }
        appsTableView?.refreshLocation()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

        let detailsViewController: DeparturesViewController = segue.destination as! DeparturesViewController
        if let station = sender as! TFCStation? {
            detailsViewController.setStation(station: station)
            return
        }
        let index = appsTableView?.indexPathForSelectedRow?.row
        if (index != nil) {
            if let station = appsTableView?.stations.getStation(index!) {
                detailsViewController.setStation(station: station);
            }
        }

    }

}


