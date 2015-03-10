//
//  ViewController.swift
//  nextMigros
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import UIKit
import MapKit
import timeforcoffeeKit
import CoreLocation

class StationsViewController: TFCBaseViewController, TFCLocationManagerDelegate {
    @IBOutlet var appsTableView : StationTableView?
    //var stations: TFCStations!
    let cellIdentifier: String = "StationTableViewCell"
    var api : APIController?
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
        appsTableView?.registerNib(UINib(nibName: "StationTableViewCell", bundle: nil), forCellReuseIdentifier: "StationTableViewCell")
        appsTableView?.rowHeight = 60
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        var detailsViewController: DeparturesViewController = segue.destinationViewController as DeparturesViewController

        var index = appsTableView?.indexPathForSelectedRow()?.row
        if (index != nil) {
            var station = appsTableView?.stations.getStation(index!)
            detailsViewController.setStation(station!);
        }
    }

}


