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

public class TFCStationBase: NSObject, NSCoding, APIControllerProtocol {
    public var name: String
    public var coord: CLLocation?
    public var st_id: String

    private var departures: [TFCDeparture]? = nil {
        didSet {
            filteredDepartures = nil
        }
    }
    private var filteredDepartures: [TFCDeparture]?

    public var calculatedDistance: Int?
    var walkingDistanceString: String?
    var walkingDistanceLastCoord: CLLocation?
    private var lastDepartureUpdate: NSDate?
    private var lastDepartureCount: Int?

    public var isLastUsed: Bool = false
    public var serializeDepartures: Bool = true

    private struct objects {
        static let  dataStore: TFCDataStore? = TFCDataStore()
    }

    private lazy var api : APIController = {
        [unowned self] in
        return APIController(delegate: self)
    }()

    struct contextData {
        var completionDelegate: TFCDeparturesUpdatedProtocol? = nil
    }

    private lazy var filteredLines:[String: [String: Bool]] = {
        [unowned self] in
        return self.getFilteredLines()
    }()

    public init(name: String, id: String, coord: CLLocation?) {
        self.name = name
        self.st_id = id
        self.coord = coord
    }

    public required init?(coder aDecoder: NSCoder) {
        self.name = aDecoder.decodeObjectForKey("name") as! String
        self.st_id = aDecoder.decodeObjectForKey("st_id") as! String
        self.coord = aDecoder.decodeObjectForKey("coord") as! CLLocation?
        self.departures = aDecoder.decodeObjectForKey("departures") as! [TFCDeparture]?
        if (self.departures?.count == 0) {
            self.departures = nil
        }
        self.walkingDistanceString = aDecoder.decodeObjectForKey("walkingDistanceString") as! String?
        self.walkingDistanceLastCoord = aDecoder.decodeObjectForKey("walkingDistanceLastCoord") as! CLLocation?
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(name, forKey: "name")
        aCoder.encodeObject(st_id, forKey: "st_id")
        aCoder.encodeObject(coord, forKey: "coord")
        if (serializeDepartures) {
            aCoder.encodeObject(departures, forKey: "departures")
        }
        aCoder.encodeObject(walkingDistanceString, forKey: "walkingDistanceString")
        aCoder.encodeObject(walkingDistanceLastCoord, forKey: "walkingDistanceLastCoord")
    }

    override public convenience init() {
        self.init(name: "doesn't exist", id: "0000", coord: nil)
    }

    public class func initWithCache(name: String, id: String, coord: CLLocation?) -> TFCStation {
        let cache: PINCache = TFCCache.objects.stations
        var newStation: TFCStation? = cache.objectForKey(id) as? TFCStation
        if (newStation == nil || newStation?.coord == nil) {
            newStation = TFCStation(name: name, id: id, coord: coord)
            cache.setObject(newStation!, forKey: newStation!.st_id)
        } else {
            let countBefore = newStation!.departures?.count
            if (countBefore > 0) {
                newStation!.removeObsoleteDepartures()
                if (countBefore > newStation!.departures?.count) {
                    cache.setObject(newStation!, forKey: newStation!.st_id)
                }
            }
            newStation!.filteredLines = newStation!.getFilteredLines()
        }
        return newStation!
    }

    public class func initWithCache(dict: [String: String]) -> TFCStation {
        var location: CLLocation? = nil;
        if let lat: String = (dict["latitude"] as String?),
            let long: String = (dict["longitude"] as String?) {
                location = CLLocation(latitude: (lat as NSString).doubleValue, longitude: (long as NSString).doubleValue)
        }
        let station = initWithCache(dict["name"] as String!, id: dict["st_id"] as String!, coord: location)
        return station
    }

    public class func isStations(results: JSON) -> Bool {
        if (results["stations"].array != nil) {
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
        TFCFavorites.sharedInstance.set(self as? TFCStation)
    }

    public func unsetFavorite() {
        TFCFavorites.sharedInstance.unset(station: self as? TFCStation)
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

    public func getNameWithFilters(cityAfter: Bool) -> String {
        return "\(getName(cityAfter))\(getFilterSign())"
    }

    private func getFilterSign() -> String {
        if (self.hasFilters()) {
            return " ✗"
        }
        return ""
    }

    public func getNameWithStarAndFilters() -> String {
        return getNameWithStarAndFilters(false)
    }
    
    public func getNameWithStarAndFilters(cityAfter: Bool) -> String {
        return "\(getNameWithStar(cityAfter))\(getFilterSign())"
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
        //var filteredLine = filteredLines[departure.getLine()]
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
        
    private func saveFilteredLines() {
        if (filteredLines.count > 0) {
            objects.dataStore?.setObject(filteredLines, forKey: "filtered\(st_id)")
        } else {
            objects.dataStore?.removeObjectForKey("filtered\(st_id)")
        }
        TFCDataStore.sharedInstance.getUserDefaults()?.setObject(NSDate(), forKey: "settingsLastUpdate")
    }
    
    private func getFilteredLines() -> [String: [String: Bool]] {
        var filteredDestinationsShared: [String: [String: Bool]]? = objects.dataStore?.objectForKey("filtered\(st_id)")?.mutableCopy() as! [String: [String: Bool]]?
        
        if (filteredDestinationsShared == nil) {
            filteredDestinationsShared = [:]
        }
        return filteredDestinationsShared!
    }

    private func addDepartures(departures: [TFCDeparture]?) {
        // don't update departures, if we get nil
        // can happen when network request didn't work properly
        if (!(departures == nil && self.departures?.count > 0)) {
            self.departures = departures
            let cache: PINCache = TFCCache.objects.stations
            cache.setObject(self, forKey: st_id)
        }
    }

    public func getDepartures() -> [TFCDeparture]? {
        return self.departures
    }

    public func getFilteredDepartures() -> [TFCDeparture]? {
        if (!hasFilters()) {
            return departures
        }
        if (filteredDepartures != nil) {
            return filteredDepartures
        }
        if (self.departures != nil) {
            filteredDepartures = []
            for (departure) in self.departures! {
                if (!self.isFiltered(departure)) {
                    filteredDepartures?.append(departure)
                }
            }
            return filteredDepartures
        }
        return nil
    }

    public func getFilteredDepartures(maxDepartures: Int) -> ArraySlice<TFCDeparture>? {
        if let filteredDepartures = getFilteredDepartures() {
            let endIndex = min(maxDepartures, filteredDepartures.count)
            return filteredDepartures[0..<endIndex]
        }
        return nil
    }

    public func updateDepartures(completionDelegate: TFCDeparturesUpdatedProtocol?) {
        updateDepartures(completionDelegate, force: false)
    }
    
    public func updateDepartures(completionDelegate: TFCDeparturesUpdatedProtocol?, force: Bool) {

        let removedDepartures = removeObsoleteDepartures()
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            var context: contextData = contextData()

            context.completionDelegate = completionDelegate
            var dontUpdate = false
            if let first = self.departures?.first {
                // don't update if the next departure is more than 30 minutes away,
                // we didn't remove any departures above
                // and this happens to be not realtime (which I assume normally isnt
                // if the first departure is that far away)
                if (!removedDepartures && first.getMinutesAsInt() > 30 && !first.isRealTime()) {
                    dontUpdate = true
                }
            }
            let settingsLastUpdated: NSDate? = TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("settingsLastUpdate") as! NSDate?
            if (force ||
                    (!dontUpdate &&
                        (self.lastDepartureUpdate == nil ||
                         self.lastDepartureUpdate?.timeIntervalSinceNow < -20 ||
                            (settingsLastUpdated != nil &&
                             self.lastDepartureUpdate?.timeIntervalSinceDate(settingsLastUpdated!) < 0
                            )
                        )
                    )
                )
            {
                self.lastDepartureUpdate = NSDate()
                self.api.getDepartures(self.st_id, context: context)

            } else {
                dispatch_async(dispatch_get_main_queue(), {
                    completionDelegate?.departuresStillCached(context, forStation: self as? TFCStation)
                    return  
                })
            }
        }
    }

    public func didReceiveAPIResults(results: JSON?, error: NSError?, context: Any?) {
            let contextInfo: contextData? = context as! contextData?
            if (results == nil || (error != nil && self.departures != nil && self.departures?.count > 0)) {
                self.setDeparturesAsOutdated()
            } else {
                self.addDepartures(TFCDeparture.withJSON(results))
            }

        dispatch_async(dispatch_get_main_queue(), {
            if (self.name == "" && results != nil) {
                self.name = TFCDeparture.getStationNameFromJson(results!)!;
            }
            contextInfo?.completionDelegate?.departuresUpdated(error, context: context, forStation: self as? TFCStation)
        })
    }

    private func setDeparturesAsOutdated() {
        if (self.departures != nil) {
            for (departure) in self.departures! {
                departure.outdated = true
            }
        }
    }

    func clearDepartures() {
        self.departures = nil
    }

    private func removeObsoleteDepartures() -> Bool {
        if (self.departures == nil || self.departures?.count == 0) {
            return false
        }
        var i = 0;
        var someRemoved = false
        for departure: TFCDeparture in self.departures! {
            if (departure.getMinutesAsInt() < 0) {
                someRemoved = true
                departures?.removeAtIndex(i)
            } else {
                i++
                //if we find one, which is not obselte, we can stop here
                break
            }
        }

        if (departures?.count == 0) {
            clearDepartures()
            someRemoved = true
        }
        return someRemoved
    }

    public func getAsDict() -> [String: String] {
        if (coord == nil) {
            return [
                "name": getName(false),
                "st_id": st_id,
            ]
        }
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

    private func getFavoriteIcon() -> UIImage {
        if (st_id == "8591306") {
            return UIImage(named: "stationicon-liip")!
        }
        return UIImage(named: "stationicon-star")!
    }

    private func getNormalIcon() -> UIImage {
        return UIImage(named: "stationicon-pin")!
    }
}

public protocol TFCDeparturesUpdatedProtocol {
    func departuresUpdated(error: NSError?, context: Any?, forStation: TFCStation?)
    func departuresStillCached(context: Any?, forStation: TFCStation?)
}


