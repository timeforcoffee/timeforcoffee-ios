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
    var currentFetch: [Int: NSURLSessionDataTask] = [:]
    
    public init(delegate: APIControllerProtocol) {
        self.delegate = delegate
    }
    
    public func searchFor(coord: CLLocationCoordinate2D) {
        var urlPath = "http://transport.opendata.ch/v1/locations?x=\(coord.latitude)&y=\(coord.longitude)&type=station";
        println(urlPath)
        self.fetchUrl(urlPath, fetchId: 1)
    }

    public func searchFor(location: String) {
        var urlPath = "http://transport.opendata.ch/v1/locations?query=\(location)*&type=station";
        println(urlPath)
        self.fetchUrl(urlPath, fetchId: 1)
    }
    
    public func getDepartures(id: String!) {
        var urlPath = "http://www.timeforcoffee.ch/api/stationboard/\(id)"
        self.fetchUrl(urlPath, fetchId: 2)
        
    }
    
    public func fetchUrl(urlPath: String, fetchId: Int) {
        let urlPathEsc = urlPath.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
        let url: NSURL = NSURL(string: urlPathEsc)!
        let session = NSURLSession.sharedSession()
        println("Start fetching data \(urlPath)")
        if (currentFetch[fetchId] != nil) {
            currentFetch[fetchId]?.cancel()
        }
        currentFetch[fetchId] = session.dataTaskWithURL(url, completionHandler: {data , response, error -> Void in
            println("Task completed")
            if(error != nil) {
                // If there is an error in the web request, print it to the console
                println(error.localizedDescription)
            }
            self.currentFetch[fetchId] = nil
            var err: NSError?
            let jsonResult = JSONValue(data)
            self.delegate.didReceiveAPIResults(jsonResult)
        })
        
        currentFetch[fetchId]?.resume()

    }
}

public protocol APIControllerProtocol {
    func didReceiveAPIResults(results: JSONValue)
}