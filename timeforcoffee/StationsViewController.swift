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
import CoreLocation

class StationsViewController: TFCBaseViewController, TFCLocationManagerDelegate {
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
        appsTableView?.registerNib(UINib(nibName: "StationTableViewCell", bundle: nil), forCellReuseIdentifier: "StationTableViewCell")
        appsTableView?.rowHeight = 60
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func viewDidAppear(animated: Bool, noReload: Bool) {
        super.viewDidAppear(animated)
        if (noReload == false) {
            appsTableView?.refreshLocation()
        }

    }
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            let gtracker = GAI.sharedInstance().defaultTracker
            gtracker.set(kGAIScreenName, value: "stations")
            gtracker.send(GAIDictionaryBuilder.createScreenView().build() as [NSObject : AnyObject]!)
        }
        appsTableView?.refreshLocation()
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        var detailsViewController: DeparturesViewController = segue.destinationViewController as! DeparturesViewController

        var index = appsTableView?.indexPathForSelectedRow()?.row
        if (index != nil) {
            var station = appsTableView?.stations.getStation(index!)
            detailsViewController.setStation(station: station!);
        }

    }

}


