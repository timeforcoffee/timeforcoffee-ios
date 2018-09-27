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
        let directionRequest:MKDirections.Request = MKDirections.Request()

        directionRequest.source = source
        directionRequest.destination = destination
        directionRequest.transportType = MKDirectionsTransportType.walking
        directionRequest.requestsAlternateRoutes = true

        let directions:MKDirections = MKDirections(request: directionRequest)


        directions.calculate(completionHandler: {
            (response: MKDirections.Response?, error: Error?) in
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
            options: UIView.AnimationOptions.curveLinear,
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
 
  
    internal override func setStationSearchIndex() {
        if #available(iOS 12, *) {
            // dont index with ios 12, intents will take care of it
        } else if #available(iOS 9, *) {
            if (Bundle.main.bundleIdentifier == "ch.opendata.timeforcoffee") {
                let item = CSSearchableItem(uniqueIdentifier: self.st_id, domainIdentifier: "stations", attributeSet: getAttributeSet())
                CSSearchableIndex.default().indexSearchableItems([item], completionHandler: { (error) -> Void in

                })
            }
        }
    }
    
    @available(iOSApplicationExtension 9.0, *)
    open override func setAttributeSet(activ:NSUserActivity) {
  
        activ.contentAttributeSet = getAttributeSet()
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
        //attributeSet.thumbnailData = nil
        if let image = UIImage(named: "time-for-coffee-icon-512.png" ) {
            attributeSet.thumbnailData = image.pngData()
        }
        return attributeSet
    }
}
