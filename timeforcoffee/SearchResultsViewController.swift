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

class SearchResultsViewController: TFCBaseViewController,  UISearchBarDelegate, UISearchControllerDelegate, UISearchResultsUpdating, UITableViewDataSource, UITableViewDelegate, APIControllerProtocol, CLLocationManagerDelegate, MGSwipeTableCellDelegate {
    @IBOutlet var appsTableView : UITableView?
    var stations = [Station]()
    let kCellIdentifier: String = "SearchResultCell"
    var api : APIController?
    var refreshControl:UIRefreshControl!
    var searchController: UISearchController!
    var favoriteStations: [String: Station] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        api = APIController(delegate: self)
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.refreshControl = UIRefreshControl()
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.appsTableView?.addSubview(refreshControl)

        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController?.searchBar.sizeToFit()
        
        self.appsTableView?.tableHeaderView = searchController?.searchBar
        
        searchController.delegate = self
        searchController.dimsBackgroundDuringPresentation = false // default is YES
        searchController.searchBar.delegate = self    // so we can monitor text changes + others
        
        definesPresentationContext = true
        populateFavoriteStations()
        initLocationManager()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.appsTableView?.setContentOffset(CGPointMake(0, 44), animated: false)
    }
    
    func updateSearchResultsForSearchController(searchController: UISearchController) {
        let whitespaceCharacterSet = NSCharacterSet.whitespaceCharacterSet()
        let strippedString = searchController.searchBar.text.stringByTrimmingCharactersInSet(whitespaceCharacterSet)

        if (strippedString != "") {
            self.api?.searchFor(strippedString)
        }
    }
    
    func refresh(sender:AnyObject)
    {
        refreshLocation()
    }
    
    // Location Manager helper stuff
    override func initLocationManager() {
        super.initLocationManager()
    }

    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        var coord = locationManagerFix(manager,didUpdateLocations: locations);
        if (coord != nil) {
            self.api?.searchFor(coord!)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stations.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell:MGSwipeTableCell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier) as MGSwipeTableCell
        
        cell.delegate = self
        cell.tag = indexPath.row
        let station = self.stations[indexPath.row]
        if (self.favoriteStations[station.st_id] != nil) {
            cell.textLabel?.text = "\(station.name) *"
        } else {
            cell.textLabel?.text = station.name
        }
        var distance = Int(currentLocation?.distanceFromLocation(station.coord) as Double!)
        if (distance > 5000) {
            let km = Int(round(Double(distance) / 1000))
            cell.detailTextLabel?.text = "\(km) Kilometer"
        } else {
            cell.detailTextLabel?.text = "\(distance) Meter"
        
            // calculate exact distance
            let currentCoordinate = currentLocation?.coordinate
            var sourcePlacemark:MKPlacemark = MKPlacemark(coordinate: currentCoordinate!, addressDictionary: nil)
            
            var destinationPlacemark:MKPlacemark = MKPlacemark(coordinate: station.coord.coordinate, addressDictionary: nil)
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
                    cell.detailTextLabel?.text = "\(time) min Fussweg, \(meters) m"
                }  else {
                    println("No response")
                    println(error?.description)
                }
                
            })
        }
        return cell
    }
    
    func swipeTableCell(cell: MGSwipeTableCell!, canSwipe direction: MGSwipeDirection) -> Bool {
        return true
    }
    
    func swipeTableCell(cell: MGSwipeTableCell!, swipeButtonsForDirection direction: MGSwipeDirection, swipeSettings: MGSwipeSettings!, expansionSettings: MGSwipeExpansionSettings!) -> [AnyObject]! {
        var buttons = []
        if (direction == MGSwipeDirection.LeftToRight) {
            let station: Station = self.stations[cell.tag]
            if (favoriteStations[station.st_id] != nil) {
                buttons = [MGSwipeButton( title:"Fav",  backgroundColor: UIColor.redColor())]
            } else {
                buttons = [MGSwipeButton( title:"Fav",  backgroundColor: UIColor.greenColor())]
            }
        }
        expansionSettings.buttonIndex = 0
        expansionSettings.fillOnTrigger = true
        return buttons
    }
    
    func swipeTableCell(cell: MGSwipeTableCell!, tappedButtonAtIndex index: Int, direction: MGSwipeDirection, fromExpansion: Bool) -> Bool {
        var favoriteStationsDict = getFavoriteStationsDict()
        let station: Station = self.stations[cell.tag]
        if (favoriteStations[station.st_id] != nil) {
            favoriteStationsDict[station.st_id] = nil
            favoriteStations[station.st_id] = nil
            var button = cell.leftButtons[0] as MGSwipeButton
            button.backgroundColor = UIColor.greenColor();
            cell.textLabel?.text = "\(station.name)"
        } else {
            favoriteStationsDict[station.st_id] =  [
                "name": station.name,
                "st_id": station.st_id,
                "latitude": station.coord.coordinate.latitude.description,
                "longitude": station.coord.coordinate.longitude.description
            ]
            favoriteStations[station.st_id] = station
            var button = cell.leftButtons[0] as MGSwipeButton
            button.backgroundColor = UIColor.redColor();
            cell.textLabel?.text = "\(station.name) *"
        }
        var sharedDefaults = NSUserDefaults(suiteName: "group.ch.liip.timeforcoffee")
        sharedDefaults?.setObject(favoriteStationsDict, forKey: "favoriteStations")
        return true
    }
    
    func getFavoriteStationsDict() -> [String: [String: String]] {
        var sharedDefaults = NSUserDefaults(suiteName: "group.ch.liip.timeforcoffee")
        var favoriteStationsShared: [String: [String: String]]? = sharedDefaults?.objectForKey("favoriteStations") as [String: [String: String]]?
        
        if (favoriteStationsShared == nil) {
            favoriteStationsShared = [:]
        }
        return favoriteStationsShared!
    }
    
    func populateFavoriteStations() {
        var favoriteStationsDict = getFavoriteStationsDict()
        for (st_id, station) in favoriteStationsDict {
            let lat = NSString(string:station["latitude"]!).doubleValue
            let long = NSString(string:station["longitude"]!).doubleValue
            var Clocation = CLLocation(latitude: lat, longitude: long)
            let station: Station = Station(name: station["name"]!, id: station["st_id"]!, coord: Clocation)
            self.favoriteStations[st_id] = station
        }
    }
    
    func didReceiveAPIResults(results: JSONValue) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        self.refreshControl.endRefreshing()
        dispatch_async(dispatch_get_main_queue(), {
            self.stations = Station.withJSON(results)
            self.appsTableView!.reloadData()
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        })
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        var detailsViewController: StationViewController = segue.destinationViewController as StationViewController
        var albumIndex = appsTableView?.indexPathForSelectedRow()?.row
//        var albumIndex = appsTableView!.indexPathForSelectedRow().row
        var selectedAlbum = self.stations[albumIndex!]
        detailsViewController.station = selectedAlbum
    }

    
}


