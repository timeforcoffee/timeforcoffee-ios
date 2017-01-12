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

public class TFCStation: TFCStationBase {
    private lazy var activity : NSUserActivity = {
        [unowned self] in
        NSUserActivity(activityType: "ch.opendata.timeforcoffee.station")
    }()

    private func getWalkingDistance(location: CLLocation?, completion: (String?) -> Void ) {
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
        directionRequest.transportType = MKDirectionsTransportType.Walking
        directionRequest.requestsAlternateRoutes = true

        let directions:MKDirections = MKDirections(request: directionRequest)


        directions.calculateDirectionsWithCompletionHandler({
            (response: MKDirectionsResponse?, error: NSError?) in
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
                DLog("No response")
                completion(nil)
                print(error?.description)
            }

        })
    }

    public func getDistanceForDisplay(location: CLLocation?, completion: (String?) -> Void) -> String {
        if (location == nil || coord == nil) {
            completion("")
            return ""
        }
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
        return ""
    }

    public func getDistanceInMeter(location: CLLocation?) -> Int? {
        if let coord = coord , distance = location?.distanceFromLocation(coord) {
            return Int(distance as Double)
        }
        return nil
    }

    private func getLastValidWalkingDistanceValid(location: CLLocation?) -> String? {
        if (walkingDistanceLastCoord != nil && walkingDistanceString != nil) {
            let distanceToLast = location?.distanceFromLocation(walkingDistanceLastCoord!)
            if (distanceToLast < 50) {
                return walkingDistanceString
            }
        }
        return nil
    }

    public func toggleIcon(button: UIButton, icon: UIView, completion: () -> Void) {
        let newImage: UIImage?

        self.toggleFavorite()

        newImage = self.getIcon()

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

    override public func setStationActivity() {
        if #available(iOS 9, *) {
            let uI = self.getAsDict()

            if (uI["st_id"] == nil) {
                DLog("station dict seems EMPTY")
                return
            }
            
            self.setStationSearchIndex()

            activity.contentAttributeSet = getAttributeSet()
            activity.title = self.getName(false)
            activity.userInfo = uI
            activity.requiredUserInfoKeys = ["st_id", "name", "longitude", "latitude"]
            activity.eligibleForSearch = true
            activity.eligibleForPublicIndexing = true
            activity.webpageURL = self.getWebLink()
            let userCalendar = NSCalendar.currentCalendar()
            let OneWeekFromNow = userCalendar.dateByAddingUnit(
                [.Day],
                value: 7,
                toDate: NSDate(),
                options: [])!
            activity.expirationDate = OneWeekFromNow
            activity.keywords = Set(getKeywords())
            activity.becomeCurrent()
        }
    }

    override public func setStationSearchIndex() {
        if #available(iOS 9, *) {
            if (NSBundle.mainBundle().bundleIdentifier == "ch.opendata.timeforcoffee") {
                let item = CSSearchableItem(uniqueIdentifier: self.st_id, domainIdentifier: "stations", attributeSet: getAttributeSet())
                CSSearchableIndex.defaultSearchableIndex().indexSearchableItems([item], completionHandler: { (error) -> Void in

                })
            }
        }
    }

    @available(iOSApplicationExtension 9.0, *)
    private func getAttributeSet() -> CSSearchableItemAttributeSet {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
        attributeSet.title = self.getName(false)
        attributeSet.supportsNavigation = 1
        attributeSet.latitude = self.getLatitude()
        attributeSet.longitude = self.getLongitude()
        attributeSet.relatedUniqueIdentifier = self.st_id
        attributeSet.keywords = getKeywords()
        return attributeSet
    }

    private func getKeywords() -> [String] {
        let abridged = self.getNameAbridged()
        var keywords = ["Fahrplan", "Timetable", "ZVV", "SBB"]
        if abridged != self.name {
            keywords.append(abridged)
        }
        return keywords
    }

}
