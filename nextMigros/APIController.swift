//
//  APIController.swift
//  nextMigros
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation

class APIController {
    
    var delegate: APIControllerProtocol
    
    init(delegate: APIControllerProtocol) {
        self.delegate = delegate
    }
    
    func searchFor(coord: CLLocationCoordinate2D) {
        
  //      var urlPath = "http://filialen.migros.ch/store/near/%28\(coord.latitude),\(coord.longitude)%29?radius=5&storeTypes=M,MM,MMM,MIG&nowOpen=true";
        var urlPath = "http://filialen.migros.ch/store/near/%28\(coord.latitude),\(coord.longitude)%29?radius=5&storeTypes=M,MM,MMM,MIG,VOI&nowOpen=true";
        
        let url: NSURL = NSURL(string: urlPath)
        let session = NSURLSession.sharedSession()
        
        println("Start fetching data")
        let task = session.dataTaskWithURL(url, completionHandler: {data , response, error -> Void in
            println("Task completed")
            if(error != nil) {
                // If there is an error in the web request, print it to the console
                println(error.localizedDescription)
            }
            var err: NSError?
            let jsonResult = JSONValue(data)
            
/*            var jsonResult = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers, error: &err) as NSArray
            if(err != nil) {
                // If there is an error parsing JSON, print it to the console
                println("JSON Error \(err!.localizedDescription)")
            }*/
            self.delegate.didReceiveAPIResults(jsonResult)
        })

        
        task.resume()
        
    }
}

protocol APIControllerProtocol {
    func didReceiveAPIResults(results: JSONValue)
}