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

public class TFCStation: NSObject,  APIControllerProtocol {
    public var name: String
    public var coord: CLLocation?
    public var st_id: String
    public var distance: CLLocationDistance?
    public var calculatedDistance: Int?
    var departures: [TFCDeparture]?
    var walkingDistanceString: String?
    var walkingDistanceLastCoord: CLLocation?
    var lastDepartureUpdate: NSDate?
    var lastDepartureCount: Int?

    lazy var api : APIController = {
        return APIController(delegate: self)
    }()

    enum contextData {
        case ValCompletionDelegate(TFCDeparturesUpdatedProtocol?)
        case ValInt(Int?)
        case ValBool(Bool?)
    }

    lazy var filteredLines:[String: [String: Bool]] = self.getFilteredLines()

    lazy var stationCache:NSCache = {
        return TFCCache.objects.stations
        }()

    public init(name: String, id: String, coord: CLLocation?) {
        self.name = name
        self.st_id = id
        self.coord = coord
    }

    override public convenience init() {
        self.init(name: "doesn't exist", id: "0000", coord: nil)
    }

    public class func initWithCache(name: String, id: String, coord: CLLocation?) -> TFCStation {
        let cache: NSCache = TFCCache.objects.stations
        var newStation: TFCStation? = cache.objectForKey(id) as TFCStation?
        if (newStation == nil) {
            println("station NOT From Cache")
            newStation = TFCStation(name: name, id: id, coord: coord)
            cache.setObject(newStation!, forKey: id)
        } else {
            println("station From Cache")
            newStation!.filteredLines = newStation!.getFilteredLines()
        }
        return newStation!
    }

    public func removeFromCache() {
        let cache: NSCache = TFCCache.objects.stations
        cache.removeObjectForKey(self.st_id)
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
        if (filteredLines.count > 0) {
            TFCStations.getUserDefaults()?.setObject(filteredLines, forKey: "filtered\(st_id)")
        } else {
            TFCStations.getUserDefaults()?.removeObjectForKey("filtered\(st_id)")
        }
        TFCStations.getUserDefaults()?.setObject(NSDate(), forKey: "settingsLastUpdate")
    }
    
    func getFilteredLines() -> [String: [String: Bool]] {
        var filteredDestinationsShared: [String: [String: Bool]]? = TFCStations.getUserDefaults()?.objectForKey("filtered\(st_id)")?.mutableCopy() as [String: [String: Bool]]?
        
        if (filteredDestinationsShared == nil) {
            filteredDestinationsShared = [:]
        }
        return filteredDestinationsShared!
    }

    public func addDepartures(departures: [TFCDeparture]?) {
        self.departures = departures
    }

    public func getDepartures() -> [TFCDeparture]? {
        return self.departures
    }

    public func updateDepartures(completionDelegate: TFCDeparturesUpdatedProtocol?, maxDepartures: Int?) {
        updateDepartures(completionDelegate, maxDepartures: maxDepartures, force: false)
    }
    public func updateDepartures(completionDelegate: TFCDeparturesUpdatedProtocol?, force: Bool) {
        updateDepartures(completionDelegate, maxDepartures: nil, force: force)
    }

    public func updateDepartures(completionDelegate: TFCDeparturesUpdatedProtocol?, maxDepartures: Int?, force: Bool) {
        let context: Dictionary<String, contextData> = [
            "completionDelegate": .ValCompletionDelegate(completionDelegate),
            "maxDepartures": .ValInt(maxDepartures)
        ]
        var settingsLastUpdated: NSDate? = TFCStations.getUserDefaults()?.objectForKey("settingsLastUpdate") as NSDate?
        if (force || lastDepartureUpdate == nil || lastDepartureUpdate?.timeIntervalSinceNow < -20 ||
            (settingsLastUpdated != nil && lastDepartureUpdate?.timeIntervalSinceDate(settingsLastUpdated!) < 0 ) ||
            (lastDepartureCount != nil && lastDepartureCount < maxDepartures)
            )
        {
            lastDepartureUpdate = NSDate()
            lastDepartureCount = maxDepartures
            self.api.getDepartures(self.st_id, context: context)
        } else {
            completionDelegate?.departuresStillCached(context, forStation: self)
        }

    }

    public func updateDepartures(completionDelegate: TFCDeparturesUpdatedProtocol?) {
        updateDepartures(completionDelegate, maxDepartures: nil)
    }

    public func didReceiveAPIResults(results: JSONValue, error: NSError?, context: Any?) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
    //    self.refreshControl.endRefreshing()
        dispatch_async(dispatch_get_main_queue(), {
            let contextInfo = context! as Dictionary<String, contextData>

            if (error != nil && self.departures != nil && self.departures?.count > 0) {
                self.setDeparturesAsOutdated()
            } else {
                var maxDepartures: Int?
                switch contextInfo["maxDepartures"]! {
                case .ValInt(let s):
                    maxDepartures = s
                default:
                    maxDepartures = nil
                }
                if (maxDepartures > 0) {
                    self.addDepartures(TFCDeparture.withJSON(results, filterStation: self, maxDepartures: maxDepartures))
                } else {
                    self.addDepartures(TFCDeparture.withJSON(results))
                }
            }
            if (self.name == "") {
                self.name = TFCDeparture.getStationNameFromJson(results)!;
            }
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false

            var completionDelegate: TFCDeparturesUpdatedProtocol?
            switch contextInfo["completionDelegate"]! {
            case .ValCompletionDelegate(let s):
                completionDelegate = s
            default:
                completionDelegate = nil
            }

            completionDelegate?.departuresUpdated(error, context: context, forStation: self)
        })
    }

    func setDeparturesAsOutdated() {
        if (self.departures != nil) {
            for (departure) in self.departures! {
                departure.outdated = true
            }
        }
    }

    func clearDepartures() {
        self.departures = nil
    }

    public func filterDepartures() {
        var i = 0
        if (self.departures != nil) {
            for (departure) in self.departures! {
                if (self.isFiltered(departure)) {
                    departures?.removeAtIndex(i)
                } else {
                    i++
                }
            }
        }
    }

    public func removeObseleteDepartures() {
        if (self.departures == nil) {
            return
        }
        var i = 0;
        for (departure: TFCDeparture) in self.departures! {
            if (departure.getMinutesAsInt() < 0) {
                departures?.removeAtIndex(i)
            } else {
                i++
            }
        }
    }

    public func getDistanceForDisplay(location: CLLocation?, completion: (String?) -> Void) -> String {
        if (location == nil) {
            completion("")
            return ""
        }
        let directDistance = getDistanceInMeter(location)
        var distanceString: String? = ""
        if (directDistance > 5000) {
            let km = Int(round(Double(directDistance!) / 1000))
            distanceString = "\(km) Kilometer"
            completion(distanceString)
        } else {
            // calculate exact distance
            //check if one is in the cache
            distanceString = getLastValidWalkingDistanceValid(location)
            if (distanceString == nil) {
                distanceString = "\(directDistance!) Meter"
                self.getWalkingDistance(location, completion)
            } else {
                completion(distanceString)
            }
        }
        return distanceString!

    }

    public func getDistanceInMeter(location: CLLocation?) -> Int? {
        return Int(location?.distanceFromLocation(coord) as Double!)
    }

    func getLastValidWalkingDistanceValid(location: CLLocation?) -> String? {
        if (walkingDistanceLastCoord != nil && walkingDistanceString != nil) {
            let distanceToLast = location?.distanceFromLocation(walkingDistanceLastCoord)
            if (distanceToLast < 50) {
                return walkingDistanceString
            }
        }
        return nil
    }

    public func getWalkingDistance(location: CLLocation?, completion: (String?) -> Void ) {
        let walkingDistanceValidString = getLastValidWalkingDistanceValid(location)
        if (walkingDistanceValidString != nil) {
                completion(walkingDistanceValidString)
                return
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

    public func toggleIcon(button: UIButton, icon: UIView, completion: () -> Void?) {
        var newImage: UIImage?

        self.toggleFavorite()

        newImage = self.getIcon()

        /*StationFavoriteButton.imageView?.alpha = 1.0
        StationIconView.transform = CGAffineTransformMakeScale(1, 1);
*/
        button.imageView?.alpha = 1.0
        icon.transform = CGAffineTransformMakeScale(1, 1);

        UIView.animateWithDuration(0.2,
            delay: 0.0,
            options: UIViewAnimationOptions.CurveLinear,
            animations: {
                icon.transform = CGAffineTransformMakeScale(0.1, 0.1);
                icon.alpha = 0.0
                return
            }, completion: { (finished:Bool) in
                button.imageView?.image = newImage
                UIView.animateWithDuration(0.2,
                    animations: {
                        icon.transform = CGAffineTransformMakeScale(1, 1);
                        icon.alpha = 1.0
                        return
                    }, completion: { (finished:Bool) in
                        completion()
                        return
                })
        })

    }


}

public protocol TFCDeparturesUpdatedProtocol {
    func departuresUpdated(error: NSError?, context: Any?, forStation: TFCStation?)
    func departuresStillCached(context: Any?, forStation: TFCStation?)
}


