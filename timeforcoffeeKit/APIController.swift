//
//  APIController.swift
//  nextMigros
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation

public class APIController {
    
    var delegate: APIControllerProtocol
    var currentFetch: NSURLSessionDataTask?
    
    public init(delegate: APIControllerProtocol) {
        self.delegate = delegate
    }
    
    public func searchFor(coord: CLLocationCoordinate2D) {
        var urlPath = "http://transport.opendata.ch/v1/locations?x=\(coord.latitude)&y=\(coord.longitude)&type=station";
        println(urlPath)
        self.fetchUrl(urlPath)
    }

    public func searchFor(location: String) {
        var urlPath = "http://transport.opendata.ch/v1/locations?query=\(location)*&type=station";
        println(urlPath)
        self.fetchUrl(urlPath)
    }
    
    public func getDepartures(id: String!) {
        var urlPath = "http://www.timeforcoffee.ch/api/stationboard/\(id)"
        self.fetchUrl(urlPath)
        
    }
    
    public func fetchUrl(urlPath: String) {
        let url: NSURL = NSURL(string: urlPath)!
        let session = NSURLSession.sharedSession()
        println("Start fetching data \(urlPath)")
        if (currentFetch != nil) {
            currentFetch?.cancel()
        }
        currentFetch = session.dataTaskWithURL(url, completionHandler: {data , response, error -> Void in
            println("Task completed")
            if(error != nil) {
                // If there is an error in the web request, print it to the console
                println(error.localizedDescription)
            }
            self.currentFetch = nil
            var err: NSError?
            let jsonResult = JSONValue(data)
            self.delegate.didReceiveAPIResults(jsonResult)
        })
        
        currentFetch?.resume()

    }
}

public protocol APIControllerProtocol {
    func didReceiveAPIResults(results: JSONValue)
}