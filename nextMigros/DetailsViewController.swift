//
//  DetailsViewController.swift
//  nextMigros
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import UIKit
import MapKit

class DetailsViewController: UIViewController, MKMapViewDelegate {
  
    @IBOutlet weak var map: MKMapView!
    @IBOutlet weak var albumCover: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var distanceLabel: UILabel!
    
    var filiale: Filiale?
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = self.filiale?.name
        
        var location = self.filiale?.coord.coordinate
        
        var region = MKCoordinateRegionMakeWithDistance(location!,1000,1000);
        
        map.delegate = self
        map.showsUserLocation = true
        map.setRegion(region, animated: true)
        
        var annotation = MKPointAnnotation()
        annotation.setCoordinate(location!)
        annotation.title = self.filiale?.name
        annotation.subtitle = self.filiale?.type
        
        map.addAnnotation(annotation)
        if (self.filiale!.imageURL != nil) {
            albumCover.image = UIImage(data: NSData(contentsOfURL: NSURL(string: self.filiale!.imageURL!)))
        }
        
        var numberOfViewControllers = self.navigationController?.viewControllers.count
        var beforeController: SearchResultsViewController? = self.navigationController?.viewControllers[(numberOfViewControllers!-2) ] as? SearchResultsViewController
        
        var currentCoordinate = beforeController?.currentLocation?.coordinate
        
        var sourcePlacemark:MKPlacemark = MKPlacemark(coordinate: currentCoordinate!, addressDictionary: nil)
        
        var destinationPlacemark:MKPlacemark = MKPlacemark(coordinate: location!, addressDictionary: nil)
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
            if response != nil{
                println("number of routes = \(response.routes.count)")
                for r in response.routes { println("route = \(r)") }
                var route: MKRoute = response.routes[0] as MKRoute;
                
       //         self.map.removeOverlay(self.map.overlays)
                
                self.map.addOverlay(route.polyline)
                self.map.setVisibleMapRect(route.polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 30.0, left: 30.0, bottom: 30.0, right: 30.0), animated: true)

//                self.map.insertOverlay(route.polyline!, atIndex: 0, level: MKOverlayLevel.AboveRoads)
                
                var time =  Int(round(route.expectedTravelTime / 60))
                var meters = Int(route.distance);
                self.distanceLabel.text = "\(time) min, \(meters) m"
                println(route.expectedTravelTime / 60)
            }
            else{
                println("No response")
            }
            println(error?.description)
        })
        
        
    }
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        println("HERE");
        if overlay is MKPolyline {
            println("FOO");
            var polylineRenderer = MKPolylineRenderer(overlay: overlay)
            polylineRenderer.strokeColor = UIColor.blueColor()
            polylineRenderer.lineWidth = 4
            return polylineRenderer
        }
        return nil
    }
}
