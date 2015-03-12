//
//  Album.swift
//  nextMigros
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit

public class TFCStation {
    public var name: String
    public var coord: CLLocation?
    public var st_id: String
    public var distance: CLLocationDistance?
    public var calculatedDistance: Int?
    var walkingDistanceString: String?
    var walkingDistanceLastCoord: CLLocation?

    lazy var filteredLines:[String: [String: Bool]] = self.getFilteredLines()

    lazy var stationCache:NSCache = {
        return TFCCache.objects.stations
        }()

    public init(name: String, id: String, coord: CLLocation?) {
        self.name = name
        self.st_id = id
        self.coord = coord
        println("init station")
    }

    deinit {
        println("deinit station")
    }

    public convenience init() {
        self.init(name: "doesn't exist", id: "0000", coord: nil)
    }

    public class func initWithCache(name: String, id: String, coord: CLLocation?) -> TFCStation {
        let cache: NSCache = TFCCache.objects.stations
        var newStation: TFCStation? = cache.objectForKey(id) as TFCStation?
        if (newStation == nil) {
            newStation = TFCStation(name: name, id: id, coord: coord)
            cache.setObject(newStation!, forKey: id)
        }
        return newStation!
    }

    public class func isStations(results: JSONValue) -> Bool {
        if (results["stations"].array? != nil) {
            return true
        }
        return false
    }
    
    public func isFavorite() -> Bool {
        return TFCStations.isFavoriteStation(self.st_id);
    }

    public func toggleFavorite() {
        if (self.isFavorite() == true) {
            self.unsetFavorite()
        } else {
            self.setFavorite()
        }
    }

    public func setFavorite() {
        TFCStations.setFavoriteStation(self)
    }

    public func unsetFavorite() {
        TFCStations.unsetFavoriteStation(self)
    }

    public func getLongitude() -> Double? {
        return coord?.coordinate.longitude
    }

    public func getLatitude() -> Double? {
        return coord?.coordinate.latitude
    }
    
    public func getName(cityAfter: Bool) -> String {
        if (cityAfter && name.match(", ")) {
            let stationName = name.replace(".*, ", template: "")
            let cityName = name.replace(", .*", template: "")
            return "\(stationName) (\(cityName))"
        }
        return name
    }
    
    public func getNameWithStar() -> String {
        return getNameWithStar(false)
    }
    
    public func getNameWithStar(cityAfter: Bool) -> String {
        if self.isFavorite() {
            return "\(getName(cityAfter)) ★"
        }
        return getName(cityAfter)
    }
    
    public func getNameWithStarAndFilters() -> String {
        return getNameWithStarAndFilters(false)
    }
    
    public func getNameWithStarAndFilters(cityAfter: Bool) -> String {
        if self.hasFilters() {
            return "\(getNameWithStar(cityAfter)) ✗"
        }
        return getNameWithStar(cityAfter)
    }
    
    public func hasFilters() -> Bool {
        return (filteredLines.count > 0)
    }
    
    public func isFiltered(departure: TFCDeparture) -> Bool {
        if (filteredLines[departure.getLine()] != nil) {
            if (filteredLines[departure.getLine()]?[departure.getDestination()] != nil) {
                return true
            }
        }
        return false
    }
    
    public func setFilter(departure: TFCDeparture) {
        var filteredLine = filteredLines[departure.getLine()]
        if (filteredLines[departure.getLine()] == nil) {
            filteredLines[departure.getLine()] = [:]
        }

        filteredLines[departure.getLine()]?[departure.getDestination()] = true
        saveFilteredLines()
    }
    
    public func unsetFilter(departure: TFCDeparture) {
        filteredLines[departure.getLine()]?[departure.getDestination()] = nil
        if((filteredLines[departure.getLine()] as [String: Bool]!).count == 0) {
            filteredLines[departure.getLine()] = nil
        }
        saveFilteredLines()

    }
        
    public func saveFilteredLines() {
        var sharedDefaults = NSUserDefaults(suiteName: "group.ch.liip.timeforcoffee")
        if (filteredLines.count > 0) {
            sharedDefaults?.setObject(filteredLines, forKey: "filtered\(st_id)")
        } else {
            sharedDefaults?.removeObjectForKey("filtered\(st_id)")
        }
    }
    
    func getFilteredLines() -> [String: [String: Bool]] {
        var sharedDefaults = NSUserDefaults(suiteName: "group.ch.liip.timeforcoffee")
        var filteredDestinationsShared: [String: [String: Bool]]? = sharedDefaults?.objectForKey("filtered\(st_id)") as [String: [String: Bool]]?
        
        if (filteredDestinationsShared == nil) {
            filteredDestinationsShared = [:]
        }
        return filteredDestinationsShared!
    }

    public func getDistanceInMeter(location: CLLocation?) -> Int? {
        return Int(location?.distanceFromLocation(coord) as Double!)
    }

    public func getWalkingDistance(location: CLLocation?, completion: (String?) -> Void ) {
        if (walkingDistanceLastCoord != nil && walkingDistanceString != nil) {

            let distanceToLast = location?.distanceFromLocation(walkingDistanceLastCoord)
            if (distanceToLast < 50) {
                completion(walkingDistanceString)
                return
            }
        }

        let currentCoordinate = location?.coordinate
        var sourcePlacemark:MKPlacemark = MKPlacemark(coordinate: currentCoordinate!, addressDictionary: nil)

        let coord = self.coord!
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
                self.walkingDistanceString = "\(meters) m, \(time) min "
                self.walkingDistanceLastCoord = location
                completion(self.walkingDistanceString)
            }  else {
                self.walkingDistanceLastCoord = nil
                self.walkingDistanceString = nil
                println("No response")
                completion(nil)
                println(error?.description)
            }

        })
    }

    public func getMapImage(completion: (UIImage) -> Void?) {
        var map: MKMapView = MKMapView()
        map.bounds.size = CGSize(width: 320,height: 150)
        let location = self.coord?.coordinate
        var region = MKCoordinateRegionMakeWithDistance(location!,200,200);
        map.setRegion(region, animated: false)

        let options = MKMapSnapshotOptions()
        options.region = map.region
        options.scale = UIScreen.mainScreen().scale
        options.size = map.frame.size

        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.startWithCompletionHandler({
            snapshot, error in
            let image = snapshot.image
            completion(image)
        })
    }


    func getAsDict() -> [String: AnyObject] {
        return [
            "name": getName(false),
            "st_id": st_id,
            "latitude": coord!.coordinate.latitude.description,
            "longitude": coord!.coordinate.longitude.description
        ]
    }

    public func getIcon() -> UIImage {
        if (isFavorite()) {
            return getFavoriteIcon()
        }
        return getNormalIcon()
    }

    func getFavoriteIcon() -> UIImage {
        if (st_id == "8591306") {
            return UIImage(named: "stationicon-liip")!
        }
        return UIImage(named: "stationicon-star")!
    }

    func getNormalIcon() -> UIImage {
        return UIImage(named: "stationicon-pin")!
    }


}

