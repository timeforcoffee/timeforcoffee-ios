//
//  APIController.swift
//  nextMigros
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation
import PINCache

final class APIController {
    
    private weak var delegate: APIControllerProtocol?
    private var currentFetch: [Int: NSURLSessionDataTask] = [:]

    private lazy var cache:PINCache = {
        return TFCCache.objects.apicalls
     }()

    init(delegate: APIControllerProtocol) {
        self.delegate = delegate
    }

    func searchFor(coord: CLLocationCoordinate2D, context: Any?) {
        let cacheKey: String = String(format: "locations?x=%.3f&y=%.3f", coord.latitude, coord.longitude)
        let urlPath: String = "http://transport.opendata.ch/v1/locations?x=\(coord.latitude)&y=\(coord.longitude)"
        self.fetchUrl(urlPath, fetchId: 1, context: context, cacheKey: cacheKey)
    }

    func searchFor(coord: CLLocationCoordinate2D) {
        searchFor(coord, context: nil)
    }
    
    func searchFor(location: String) {
        let name = location.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
        let cacheKey = "stations/\(name)"
        let urlPath = "http://www.timeforcoffee.ch/api/zvv/stations/\(name)*";
        //let urlPath = "http://transport.opendata.ch/v1/locations?query=\(name)*";

        self.fetchUrl(urlPath, fetchId: 1, cacheKey: cacheKey)
    }

    func getDepartures(id: String!) {
        getDepartures(id, context: nil)
    }
    
    func getDepartures(id: String!, context: Any?) {
        let urlPath = "http://www.timeforcoffee.ch/api/zvv/stationboard/\(id)"
        self.fetchUrl(urlPath, fetchId: 2, context: context, cacheKey: nil)
    }
    
    private func fetchUrl(urlPath: String, fetchId: Int, cacheKey: String?) {
        fetchUrl(urlPath, fetchId: fetchId, context: nil, cacheKey: cacheKey, counter: 0)
    }

    private func fetchUrl(urlPath: String, fetchId: Int, context: Any?, cacheKey: String?) {
        fetchUrl(urlPath, fetchId: fetchId, context: context, cacheKey: cacheKey, counter: 0)
    }

    private func fetchUrl(urlPath: String, fetchId: Int, context: Any?, cacheKey: String?, counter: Int) {

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            if (cacheKey != nil && self.cache.objectForKey(cacheKey!) as? NSData != nil) {
                let result = JSON(data: self.cache.objectForKey(cacheKey!) as! NSData);
                self.delegate?.didReceiveAPIResults(result, error: nil, context: context)
            } else {
                let url: NSURL = NSURL(string: urlPath)!
                let absUrl = url.absoluteString
                NSLog("Start fetching data %@", absUrl)


                if (fetchId == 1 && self.currentFetch[fetchId] != nil) {
                    NSLog("cancel current fetch")
                    self.currentFetch[fetchId]?.cancel()
                }
                
                let session2 = TFCURLSession.sharedInstance.session
                let dataFetch: NSURLSessionDataTask? = session2.dataTaskWithURL(url, completionHandler: {data , response, error -> Void in

                    NSLog("Task completed")
                    if(error != nil) {
                        // If there is an error in the web request, print it to the console
                        NSLog(error!.localizedDescription)
                        // 1001 == timeout => just retry
                        if (error!.code == -1001) {
                            let newcounter = counter + 1
                            // don't do it more than 5 times
                            if (newcounter <= 5) {
                                self.delegate?.didReceiveAPIResults(nil, error: error, context: context)
                                NSLog("Retry #\(newcounter) fetching \(urlPath)")
                                self.fetchUrl(urlPath, fetchId: fetchId, context: context, cacheKey: cacheKey, counter: newcounter)
                            }
                        }
                    }
                    if (fetchId == 1) {
                        self.currentFetch[fetchId] = nil
                    }
                    let jsonResult = JSON(data: data!)
                    //jsonResult.boolValue is false, when data was not parseable. Don't cache it in that case
                    if (jsonResult.boolValue == true && error == nil && cacheKey != nil) {
                        self.cache.setObject(data!, forKey: cacheKey!)
                    }
                    self.delegate?.didReceiveAPIResults(jsonResult, error: error, context: context)
                })
                dataFetch?.resume()
                NSLog("dataTask resumed")
                if (dataFetch != nil) {
                    self.currentFetch[fetchId] = dataFetch
                }
            }

        }
    }
}

public protocol APIControllerProtocol: class {
    func didReceiveAPIResults(results: JSON?, error: NSError?, context: Any?)
}