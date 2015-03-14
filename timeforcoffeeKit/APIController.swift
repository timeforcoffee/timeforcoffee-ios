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

    lazy var session:NSURLSession = {
        return NSURLSession.sharedSession()
    }()

    lazy var cache:NSCache = {
        return TFCCache.objects.apicalls
     }()

    public init(delegate: APIControllerProtocol) {
        self.delegate = delegate
    }
    
    public func searchFor(coord: CLLocationCoordinate2D) {
        let cacheKey: String = String(format: "locations?x=%.3f&y=%.3f", coord.latitude, coord.longitude)
        let urlPath: String = "http://transport.opendata.ch/v1/locations?x=\(coord.latitude)&y=\(coord.longitude)"

        self.fetchUrl(urlPath, fetchId: 1, cacheKey: cacheKey)
    }

    public func searchFor(location: String) {
        let name = location.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
        let cacheKey = "stations/\(name)"
        let urlPath = "http://www.timeforcoffee.ch/api/zvv/stations/\(name)*";

        self.fetchUrl(urlPath, fetchId: 1, cacheKey: cacheKey)
    }

    public func getDepartures(id: String!) {
        getDepartures(id, context: nil)
    }
    
    public func getDepartures(id: String!, context: Any?) {
        var urlPath = "http://www.timeforcoffee.ch/api/zvv/stationboard/\(id)"
        self.fetchUrl(urlPath, fetchId: 2, context: context, cacheKey: nil)
    }
    
    func fetchUrl(urlPath: String, fetchId: Int, cacheKey: String?) {
        fetchUrl(urlPath, fetchId: fetchId, context: nil, cacheKey: cacheKey)
    }

    func fetchUrl(urlPath: String, fetchId: Int, context: Any?, cacheKey: String?) {
        if (cacheKey != nil && cache.objectForKey(cacheKey!) != nil) {
            let result = JSONValue(cache.objectForKey(cacheKey!) as NSData!);
            self.delegate.didReceiveAPIResults(result, error: nil, context: context)
        } else {
            let urlPathEsc = urlPath.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
            let url: NSURL = NSURL(string: urlPathEsc)!
            println("Start fetching data \(urlPath)")
            if (currentFetch[fetchId] != nil) {
                currentFetch[fetchId]?.cancel()
            }
            let session2 = self.session
            var cachePolicy = NSURLRequestCachePolicy.UseProtocolCachePolicy
            /* if a cacheKey is set, we may load it from the NSURL Cache (it may be there, but not in NSCache, because of eviction in NSCache. As our own Cache always caches it at least longer than any NSURLCache anyway, that's not a problem)
            */
            if (cacheKey != nil) {
                cachePolicy = NSURLRequestCachePolicy.ReturnCacheDataElseLoad
            }
            let request = NSURLRequest(URL: url, cachePolicy: cachePolicy, timeoutInterval: 10.0)

            currentFetch[fetchId] = session2.dataTaskWithRequest(request, completionHandler: {data , response, error -> Void in

                println("Task completed")
                if(error != nil) {
                    // If there is an error in the web request, print it to the console
                    println(error.localizedDescription)
                }
                self.currentFetch[fetchId] = nil
                var err: NSError?
                let jsonResult = JSONValue(data)
                if (error == nil && cacheKey != nil) {
                    self.cache.setObject(data, forKey: cacheKey!)
                }
                println("HHHH")
                println(error)
                self.delegate.didReceiveAPIResults(jsonResult, error: error, context: context)
            })
            
            currentFetch[fetchId]?.resume()
        }
    }
}

public protocol APIControllerProtocol {
    func didReceiveAPIResults(results: JSONValue, error: NSError?, context: Any?)
}