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
        return NSCache()
    }()

    public init(delegate: APIControllerProtocol) {
        self.delegate = delegate
    }
    
    public func searchFor(coord: CLLocationCoordinate2D) {
        var urlPath: String = String(format: "http://transport.opendata.ch/v1/locations?x=%.4f&y=%.4f", coord.latitude, coord.longitude)
        if (cache.objectForKey(urlPath) != nil) {
            let result = JSONValue(cache.objectForKey(urlPath) as NSData!);
            self.delegate.didReceiveAPIResults(result, error: nil, context: nil)
        } else {
            self.fetchUrl(urlPath, fetchId: 1, cacheRequest: true)
        }
    }

    public func searchFor(location: String) {
        let name = location.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
        let urlPath = "http://www.timeforcoffee.ch/api/zvv/stations/\(name)*";

        self.fetchUrl(urlPath, fetchId: 1, cacheRequest: true)
    }
    public func getDepartures(id: String!) {
        getDepartures(id, context: nil)
    }
    
    public func getDepartures(id: String!, context: Any?) {
        var urlPath = "http://www.timeforcoffee.ch/api/zvv/stationboard/\(id)"
        self.fetchUrl(urlPath, fetchId: 2, context: context, cacheRequest: false)
    }
    
    func fetchUrl(urlPath: String, fetchId: Int, cacheRequest: Bool) {
        fetchUrl(urlPath, fetchId: fetchId, context: nil, cacheRequest: cacheRequest)
    }

    func fetchUrl(urlPath: String, fetchId: Int, context: Any?, cacheRequest: Bool) {
        if (cacheRequest && cache.objectForKey(urlPath) != nil) {
            let result = JSONValue(cache.objectForKey(urlPath) as NSData!);
            self.delegate.didReceiveAPIResults(result, error: nil, context: context)
        } else {
            let urlPathEsc = urlPath.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
            let url: NSURL = NSURL(string: urlPathEsc)!
            println("Start fetching data \(urlPath)")
            if (currentFetch[fetchId] != nil) {
                currentFetch[fetchId]?.cancel()
            }
            let session2 = self.session
            let request = NSURLRequest(URL: url, cachePolicy: NSURLRequestCachePolicy.ReturnCacheDataElseLoad, timeoutInterval: 10.0)


            currentFetch[fetchId] = session2.dataTaskWithRequest(request, completionHandler: {data , response, error -> Void in

                println("Task completed")
                if(error != nil) {
                    // If there is an error in the web request, print it to the console
                    println(error.localizedDescription)
                }
                self.currentFetch[fetchId] = nil
                var err: NSError?
                let jsonResult = JSONValue(data)
                if (error == nil && cacheRequest) {
                    let HTTPResponse: NSHTTPURLResponse = response as NSHTTPURLResponse
                    let url: String? = HTTPResponse.URL?.absoluteString
                    if (url != nil) {
                        self.cache.setObject(data, forKey: url!)
                    }
                }
                self.delegate.didReceiveAPIResults(jsonResult, error: error, context: context)
            })
            
            currentFetch[fetchId]?.resume()
        }
    }
}

public protocol APIControllerProtocol {
    func didReceiveAPIResults(results: JSONValue, error: NSError?, context: Any?)
}