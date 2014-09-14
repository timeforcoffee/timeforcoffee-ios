//
//  DetailsViewController.swift
//  nextMigros
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import UIKit
import MapKit

class DetailsViewController: UIViewController {
  
    @IBOutlet weak var map: MKMapView!
    @IBOutlet weak var albumCover: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    var filiale: Filiale?
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = self.filiale?.name
        
        var location = self.filiale?.coord.coordinate
        
        var region = MKCoordinateRegionMakeWithDistance(location!,1000,1000);
        
        map.setRegion(region, animated: true)
        
        var annotation = MKPointAnnotation()
        annotation.setCoordinate(location!)
        annotation.title = self.filiale?.name
        annotation.subtitle = self.filiale?.type
        
        map.addAnnotation(annotation)
        if (self.filiale!.imageURL != nil) {
            albumCover.image = UIImage(data: NSData(contentsOfURL: NSURL(string: self.filiale!.imageURL!)))
        }
    }
}
