//
//  TFCStation.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 21.06.15.
//  Copyright © 2015 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit
import CoreSpotlight
import MobileCoreServices
import Intents

open class TFCStation: TFCStationBase {
    fileprivate lazy var activity : NSUserActivity = {
        [unowned self] in
        NSUserActivity(activityType: "ch.opendata.timeforcoffee.station")
    }()

    fileprivate func getWalkingDistance(_ location: CLLocation?, completion: @escaping (String?) -> Void ) {
        let walkingDistanceValidString = getLastValidWalkingDistanceValid(location)
        if (walkingDistanceValidString != nil) {
            completion(walkingDistanceValidString)
            return
        }

        let currentCoordinate = location?.coordinate
        let sourcePlacemark:MKPlacemark = MKPlacemark(coordinate: currentCoordinate!, addressDictionary: nil)

        if (self.coord == nil) {
            completion(nil)
            return
        }
        let coord = self.coord!
        let destinationPlacemark:MKPlacemark = MKPlacemark(coordinate: coord.coordinate, addressDictionary: nil)
        let source:MKMapItem = MKMapItem(placemark: sourcePlacemark)
        let destination:MKMapItem = MKMapItem(placemark: destinationPlacemark)
        let directionRequest:MKDirectionsRequest = MKDirectionsRequest()

        directionRequest.source = source
        directionRequest.destination = destination
        directionRequest.transportType = MKDirectionsTransportType.walking
        directionRequest.requestsAlternateRoutes = true

        let directions:MKDirections = MKDirections(request: directionRequest)


        directions.calculate(completionHandler: {
            (response: MKDirectionsResponse?, error: Error?) in
            if error != nil{
                DLog("Error")
            }
            if response != nil {
                let route: MKRoute = response!.routes[0] as MKRoute;
                let time =  Int(round(route.expectedTravelTime / 60))
                let meters = Int(route.distance);
                self.walkingDistanceString = "\(meters) m, \(time) min "
                self.walkingDistanceLastCoord = location
                TFCStationBase.saveToPincache(self)

                completion(self.walkingDistanceString)
            }  else {
                self.walkingDistanceLastCoord = nil
                self.walkingDistanceString = nil
                DLog("No response \(String(describing: error))")
                completion(nil)
            }

        })
    }

    open func getDistanceForDisplay(_ location: CLLocation?, completion: @escaping (String?) -> Void) -> String {
        if (location == nil || coord == nil) {
            completion("")
            return ""
        }
        if let location = location {
            let directDistance = getDistanceInMeter(location)
            var distanceString: String? = ""
            if let directDistance = directDistance {
                if (directDistance > 5000) {
                    let km = Int(round(Double(directDistance) / 1000))
                    distanceString = "\(km) Kilometer"
                    completion(distanceString)
                } else {
                    // calculate exact distance
                    //check if one is in the cache
                    distanceString = getLastValidWalkingDistanceValid(location)
                    if (distanceString == nil) {
                        distanceString = "\(directDistance) Meter"
                        self.getWalkingDistance(location, completion: completion)
                    } else {
                        completion(distanceString)
                    }
                }
            }
            if let distanceString = distanceString {
                return distanceString
            }
        }
        return ""
    }

    open func getDistanceInMeter(_ location: CLLocation) -> Int? {
        if let coord = coord {
            let distance = location.distance(from: coord)
            return Int(distance as Double)
        }
        return nil
    }

    fileprivate func getLastValidWalkingDistanceValid(_ location: CLLocation?) -> String? {
        if (walkingDistanceLastCoord != nil && walkingDistanceString != nil) {
            if let distanceToLast = location?.distance(from: walkingDistanceLastCoord!) {
                if (distanceToLast < 50) {
                    return walkingDistanceString
                }
            }
        }
        return nil
    }

    open func toggleIcon(_ button: UIButton, icon: UIView, completion: @escaping () -> Void) {
        let newImage: UIImage?

        self.toggleFavorite()

        newImage = self.getIcon()

        button.imageView?.alpha = 1.0
        icon.transform = CGAffineTransform(scaleX: 1, y: 1);

        UIView.animate(withDuration: 0.2,
            delay: 0.0,
            options: UIViewAnimationOptions.curveLinear,
            animations: {
                icon.transform = CGAffineTransform(scaleX: 0.1, y: 0.1);
                icon.alpha = 0.0
                return
            }, completion: { (finished:Bool) in
                button.imageView?.image = newImage
                UIView.animate(withDuration: 0.2,
                    animations: {
                        icon.transform = CGAffineTransform(scaleX: 1, y: 1);
                        icon.alpha = 1.0
                        return
                    }, completion: { (finished:Bool) in
                        completion()
                        return
                })
        })
        
    }

    override open func setStationActivity() {
        if #available(iOS 9, *) {
            let uI = self.getAsDict()

            if (uI["st_id"] == nil) {
                DLog("station dict seems EMPTY")
                return 
            }
            
            self.setStationSearchIndex()

            activity.contentAttributeSet = getAttributeSet()
            activity.title = "Show departures from \(self.getName(false))"
            activity.userInfo = uI
            activity.requiredUserInfoKeys = ["st_id", "name", "longitude", "latitude"]
            activity.isEligibleForSearch = true
            activity.isEligibleForPublicIndexing = true
            activity.isEligibleForHandoff = true
            if #available(iOSApplicationExtension 12.0, *) {
                activity.isEligibleForPrediction = true
                activity.persistentIdentifier = NSUserActivityPersistentIdentifier(self.st_id)
                if let center = TFCLocationManager.getCurrentLocation()?.coordinate {
                    let sc = INShortcut(userActivity: activity)
                    let rsc = INRelevantShortcut(shortcut: sc)
                    let region = CLCircularRegion(center: center,radius: CLLocationDistance(300), identifier: "currentLoc")
                    rsc.relevanceProviders = [INLocationRelevanceProvider(region: region)]
                    INRelevantShortcutStore.default.setRelevantShortcuts([rsc])
                }
            }
            activity.webpageURL = self.getWebLink()
            let userCalendar = Calendar.current
            let FourWeeksFromNow = (userCalendar as NSCalendar).date(
                byAdding: [.day],
                value: 28,
                to: Date(),
                options: [])!
            activity.expirationDate = FourWeeksFromNow
            activity.keywords = Set(getKeywords())
            activity.becomeCurrent()
        }
    }

    @available(iOSApplicationExtension 9.0, *)
    fileprivate func getAttributeSet() -> CSSearchableItemAttributeSet {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
        attributeSet.title = self.getName(false)
        attributeSet.supportsNavigation = 1
        attributeSet.latitude = self.getLatitude() as NSNumber?
        attributeSet.longitude = self.getLongitude() as NSNumber?
        attributeSet.relatedUniqueIdentifier = self.st_id
        attributeSet.keywords = getKeywords()
        return attributeSet
    }

    fileprivate func getKeywords() -> [String] {
        let abridged = self.getNameAbridged()
        var keywords = ["Fahrplan", "Timetable", "ZVV", "SBB"]
        if abridged != self.name {
            keywords.append(abridged)
        }
        return keywords
    }

    override open func setStationSearchIndex() {
        if #available(iOS 9, *) {
            if (Bundle.main.bundleIdentifier == "ch.opendata.timeforcoffee") {
                let item = CSSearchableItem(uniqueIdentifier: self.st_id, domainIdentifier: "stations", attributeSet: getAttributeSet())
                CSSearchableIndex.default().indexSearchableItems([item], completionHandler: { (error) -> Void in

                })
            }
        }
    }
}
