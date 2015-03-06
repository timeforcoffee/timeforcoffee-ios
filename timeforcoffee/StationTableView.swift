//
//  StationTableView.swift
//  timeforcoffee
//
//  Created by Jan Hug on 04.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import UIKit
import MapKit
import timeforcoffeeKit
import CoreLocation

class StationTableView: UITableView, UITableViewDelegate, UITableViewDataSource,APIControllerProtocol, TFCLocationManagerDelegate, UISearchBarDelegate, UISearchControllerDelegate, UISearchResultsUpdating {
    
    var refreshControl:UIRefreshControl!
    lazy var stations: TFCStations = {return TFCStations();}()
    lazy var locManager: TFCLocationManager = self.lazyInitLocationManager()
    lazy var api : APIController = { return APIController(delegate: self)}()
    var networkErrorMsg: String?
    var searchController: UISearchController!
    var showFavorites: Bool?
    var stationsViewController: StationsViewController?

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        /* Adding the refresh controls */
        self.dataSource = self

        self.refreshControl = UIRefreshControl()
        self.refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.refreshControl.backgroundColor = UIColor(red: 242.0/255.0, green: 243.0/255.0, blue: 245.0/255.0, alpha: 1.0)
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.addSubview(refreshControl)


        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self

        searchController.delegate = self
        searchController.dimsBackgroundDuringPresentation = false // default is YES
        searchController.searchBar.delegate = self    // so we can monitor text changes + others
        self.tableHeaderView = searchController?.searchBar

        self.registerNib(UINib(nibName: "StationTableViewCell", bundle: nil), forCellReuseIdentifier: "StationTableViewCell")

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBecomeActive:", name: "UIApplicationDidBecomeActiveNotification", object: nil)
    }


    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func applicationDidBecomeActive(notification: NSNotification) {
        if (!(self.searchController?.searchBar.text.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0)) {
            refreshLocation()
        }
    }

    func refresh(sender:AnyObject)
    {
        refreshLocation()
    }

    func refreshLocation() {
        if ((showFavorites) == true) {
            self.stations.loadFavorites(locManager.currentLocation)
            self.reloadData()
            self.refreshControl.endRefreshing()
        } else {
            self.locManager.refreshLocation()
        }
    }

    internal func lazyInitLocationManager() -> TFCLocationManager {
        return TFCLocationManager(delegate: self)
    }

    internal func locationFixed(coord: CLLocationCoordinate2D?) {
        if (coord != nil) {
            self.api.searchFor(coord!)
        }
    }

    func updateSearchResultsForSearchController(searchController: UISearchController) {
        let whitespaceCharacterSet = NSCharacterSet.whitespaceCharacterSet()
        let strippedString = searchController.searchBar.text.stringByTrimmingCharactersInSet(whitespaceCharacterSet)

        if (strippedString != "") {
            stations.clear()
            self.api.searchFor(strippedString)
        }
    }

    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        refreshLocation()
    }


    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (stations.count() == nil || stations.count() == 0) {
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


        let station = self.stations.getStation(indexPath.row)
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
        self.stationsViewController?.performSegueWithIdentifier("SegueToStationView", sender: tableView)
    }
    

    func didReceiveAPIResults(results: JSONValue, error: NSError?, context: Any?) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        dispatch_async(dispatch_get_main_queue(), {
            if (error != nil && error?.code != -999) {
                self.networkErrorMsg = "Network error. Please try again"
            } else {
                self.networkErrorMsg = nil
            }
            self.stations.addWithJSON(results)
            self.reloadData()
            self.refreshControl.endRefreshing()

        })
    }


}
