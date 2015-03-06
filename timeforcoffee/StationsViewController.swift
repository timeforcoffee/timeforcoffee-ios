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

class StationsViewController: TFCBaseViewController, UISearchBarDelegate, UISearchControllerDelegate, UISearchResultsUpdating, UITableViewDataSource, UITableViewDelegate, APIControllerProtocol, TFCLocationManagerDelegate {
    @IBOutlet var appsTableView : UITableView?
    var stations: TFCStations!
    let cellIdentifier: String = "StationTableViewCell"
    var api : APIController?
    var refreshControl:UIRefreshControl!
    var searchController: UISearchController!
    var networkErrorMsg: String? = nil
    var showFavorites: Bool = false
    var pageIndex: Int?


    override func viewDidLoad() {
        super.viewDidLoad()
        api = APIController(delegate: self)
        stations = TFCStations()
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.refreshControl = UIRefreshControl()
        self.refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.appsTableView?.addSubview(refreshControl)
        self.refreshControl.backgroundColor = UIColor(red: 242.0/255.0, green: 243.0/255.0, blue: 245.0/255.0, alpha: 1.0)
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController?.searchBar.sizeToFit()

        var favButton = UIBarButtonItem(title: "Favs", style: UIBarButtonItemStyle.Plain, target: self, action: "favButtonClicked:")

        let favFont = UIFont.systemFontOfSize(15)
        let favButtonAttr = [NSFontAttributeName: favFont]
        favButton.setTitleTextAttributes(favButtonAttr, forState: UIControlState.Normal)

        self.navigationItem.leftBarButtonItem = favButton
        favButton.tintColor = UIColor.blackColor()

        self.appsTableView?.tableHeaderView = searchController?.searchBar

        searchController.delegate = self
        searchController.dimsBackgroundDuringPresentation = false // default is YES
        searchController.searchBar.delegate = self    // so we can monitor text changes + others

        definesPresentationContext = true
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBecomeActive:", name: "UIApplicationDidBecomeActiveNotification", object: nil)
        appsTableView?.registerNib(UINib(nibName: "StationTableViewCell", bundle: nil), forCellReuseIdentifier: "StationTableViewCell")

    }

    deinit {
       NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func applicationDidBecomeActive(notification: NSNotification) {
        if (!(self.searchController?.searchBar.text.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0)) {
            refreshLocation()
        }
    }

    func favButtonClicked(sender: UIBarButtonItem) {
        var font: UIFont
        if (!showFavorites) {
            showFavorites = true
            font = UIFont.boldSystemFontOfSize(15)
        } else {
            showFavorites = false
            font = UIFont.systemFontOfSize(15)
            stations?.clear()
            self.appsTableView?.reloadData()
        }

        let buttonAttr = [NSFontAttributeName: font]

        sender.setTitleTextAttributes(buttonAttr, forState: UIControlState.Normal)

        refreshLocation()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        //if favorites are show reload them, since they could have changed
        if (showFavorites) {
            stations.loadFavorites(locManager.currentLocation)
        } else {
            if (self.stations.count() == nil) {
                refreshLocation()
            }
        }
        self.appsTableView?.reloadData()
    }

    func updateSearchResultsForSearchController(searchController: UISearchController) {
        let whitespaceCharacterSet = NSCharacterSet.whitespaceCharacterSet()
        let strippedString = searchController.searchBar.text.stringByTrimmingCharactersInSet(whitespaceCharacterSet)

        if (strippedString != "") {
            stations?.clear()
            self.api?.searchFor(strippedString)
        }
    }

    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
         refreshLocation()
    }

    func refresh(sender:AnyObject)
    {
        refreshLocation()
    }

    override func locationFixed(coord: CLLocationCoordinate2D?) {
        println("locationFixed")
        if (coord != nil) {
            self.api?.searchFor(coord!)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (stations == nil || stations.count() == nil || stations.count() == 0) {
            return 1
        }
        return stations.count()!
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("StationTableViewCell", forIndexPath: indexPath) as StationTableViewCell

        //cell.delegate = self
        cell.tag = indexPath.row

        let textLabel = cell.StationNameLabel
        let detailTextLabel = cell.StationDescriptionLabel

        let stationsCount = stations.count()

        if (stationsCount == nil || stationsCount == 0) {
            cell.userInteractionEnabled = false;
            if (stationsCount == nil) {
                textLabel?.text = NSLocalizedString("Loading", comment: "Loading ..")
                detailTextLabel?.text = ""
            } else {
                textLabel?.text = NSLocalizedString("No stations found.", comment: "")

                if (self.networkErrorMsg != nil) {
                    detailTextLabel?.text = self.networkErrorMsg
                } else {
                    detailTextLabel?.text = ""
                }
            }
            return cell
        }
        cell.userInteractionEnabled = true;


        let station = self.stations!.getStation(indexPath.row)
        textLabel?.text = station.getNameWithStar()

        if (locManager.currentLocation == nil) {
            detailTextLabel?.text = ""
            return cell
        }

        if (station.coord != nil) {
            var distance = Int(locManager.currentLocation?.distanceFromLocation(station.coord) as Double!)
            if (distance > 5000) {
                let km = Int(round(Double(distance) / 1000))
                detailTextLabel?.text = "\(km) Kilometer"
            } else {
                detailTextLabel?.text = "\(distance) Meter"
                // calculate exact distance
                let currentCoordinate = locManager.currentLocation?.coordinate
                var sourcePlacemark:MKPlacemark = MKPlacemark(coordinate: currentCoordinate!, addressDictionary: nil)

                let coord = station.coord!
                var destinationPlacemark:MKPlacemark = MKPlacemark(coordinate: coord.coordinate, addressDictionary: nil)
                var source:MKMapItem = MKMapItem(placemark: sourcePlacemark)
                var destination:MKMapItem = MKMapItem(placemark: destinationPlacemark)
                var directionRequest:MKDirectionsRequest = MKDirectionsRequest()

                directionRequest.setSource(source)
                directionRequest.setDestination(destination)
                directionRequest.transportType = MKDirectionsTransportType.Walking
                directionRequest.requestsAlternateRoutes = true

                var directions:MKDirections = MKDirections(request: directionRequest)
                directions.calculateDirectionsWithCompletionHandler({
                    (response: MKDirectionsResponse!, error: NSError?) in
                    if error != nil{
                        println("Error")
                    }
                    if response != nil {
                        for r in response.routes { println("route = \(r)") }
                        var route: MKRoute = response.routes[0] as MKRoute;


                        var time =  Int(round(route.expectedTravelTime / 60))
                        var meters = Int(route.distance);
                        let walking = NSLocalizedString("walking", comment: "Walking")
                        detailTextLabel?.text = "\(time) min \(walking), \(meters) m"
                    }  else {
                        println("No response")
                        println(error?.description)
                    }

                })
            }
        } else {
            detailTextLabel?.text = ""
        }
        return cell
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.performSegueWithIdentifier("SegueToStationView", sender: tableView)
    }


    func didReceiveAPIResults(results: JSONValue, error: NSError?, context: Any?) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        dispatch_async(dispatch_get_main_queue(), {
            if (error != nil && error?.code != -999) {
                self.networkErrorMsg = "Network error. Please try again"
            } else {
                self.networkErrorMsg = nil
            }
            self.stations!.addWithJSON(results)
            self.appsTableView?.reloadData()
            self.refreshControl.endRefreshing()

        })
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        var detailsViewController: DeparturesViewController = segue.destinationViewController as DeparturesViewController

        var index = appsTableView?.indexPathForSelectedRow()?.row
        if (index != nil) {
            var station = stations.getStation(index!)
            detailsViewController.setStation(station);
        }
    }

    func refreshLocation() {
        if (showFavorites) {
            self.stations?.loadFavorites(locManager.currentLocation)
            self.appsTableView?.reloadData()
        } else {
            super.locManager.refreshLocation()
        }
    }
}


