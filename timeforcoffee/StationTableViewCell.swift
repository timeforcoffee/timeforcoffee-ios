//
//  StationTableViewCell.swift
//  timeforcoffee
//
//  Created by Jan Hug on 04.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import UIKit
import timeforcoffeeKit
import MapKit

class StationTableViewCell: UITableViewCell {
    @IBOutlet weak var StationIconView: UIView!
    @IBOutlet weak var StationNameLabel: UILabel!
    @IBOutlet weak var StationDescriptionLabel: UILabel!
    @IBOutlet weak var StationFavoriteButton: UIButton!

    lazy var station: TFCStation = TFCStation()

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        StationIconView.layer.cornerRadius = StationIconView.layer.bounds.width / 2
        StationIconView.clipsToBounds = true
        
        StationFavoriteButton.addTarget(self, action: "favoriteButtonTouched:", forControlEvents: UIControlEvents.TouchUpInside)
    }

    deinit {
        println("cell deinit")
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func favoriteButtonTouched(sender: UIButton) {
        println(station.isFavorite())
        station.toggleFavorite()
        drawFavoriteIcon()
    }

    func drawCell() {
        drawFavoriteIcon()
        let parent = self.superview?.superview as StationTableView
        let locManager = parent.locManager
        StationNameLabel?.text = station.getNameWithStar()

        if (locManager.currentLocation == nil) {
            StationDescriptionLabel.text = ""
            return
        }

        if (station.coord != nil) {
            var distance = Int(locManager.currentLocation?.distanceFromLocation(station.coord) as Double!)
            if (distance > 5000) {
                let km = Int(round(Double(distance) / 1000))
                StationDescriptionLabel.text = "\(km) Kilometer"
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
                        self.StationDescriptionLabel.text = "\(time) min \(walking), \(meters) m"
                    }  else {
                        println("No response")
                        println(error?.description)
                    }

                })
            }
        } else {
            StationDescriptionLabel.text = ""
        }
    }

    func drawFavoriteIcon() {
        if (station.isFavorite() == true) {
            StationIconView.backgroundColor = UIColor(red: 249, green: 205, blue: 70)
        } else {
            StationIconView.backgroundColor = UIColor(red: 197, green: 197, blue: 197)
        }
    }

}
