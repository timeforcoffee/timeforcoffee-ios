//
//  APIController.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation

final class APIController {
    
    private weak var delegate: APIControllerProtocol?
    private var currentFetch: [Int: NSURLSessionDataTask] = [:]

    private lazy var cache:PINCache = {
        return TFCCache.objects.apicalls
     }()

    init(delegate: APIControllerProtocol?) {
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
        let urlPath:String
        // search over all possible locations if outside of switzerland
        if (TFCLocationManager.getISOCountry() != "CH") {
            urlPath = "http://transport.opendata.ch/v1/locations?query=\(name)*";
        } else {
            urlPath = "http://www.timeforcoffee.ch/api/zvv/stations/\(name)*"
        }

        self.fetchUrl(urlPath, fetchId: 1, cacheKey: cacheKey)
    }

    func getDepartures(id: String!) {
        getDepartures(id, context: nil)
    }
    
    func getDepartures(id: String!, context: Any?) {
        let urlPath:String
        // we return date from opendata, when we're not in switzerland (TFC only has
        //  data for switzerland, but transport.opendata.ch may have for other stations
        //  as well)
        //  but actually each station should know, if it's in switzerland or not, but that
        //  needs a whole different infrastructure
        if (TFCLocationManager.getISOCountry() != "CH") {
            urlPath = "http://transport.opendata.ch/v1/stationboard?id=\(id)&limit=40"
        } else {
            urlPath = "http://www.timeforcoffee.ch/api/zvv/stationboard/\(id)"
        }
        self.fetchUrl(urlPath, fetchId: 2, context: context, cacheKey: nil)
    }

    func getStationInfo(id: String!) -> JSON? {
        let urlPath = "http://transport.opendata.ch/v1/locations?query=\(id)"
        let cacheKey = "stationsinfo/\(id)"
        return self.fetchUrlSync(urlPath, cacheKey: cacheKey)
    }
    
    private func fetchUrl(urlPath: String, fetchId: Int, cacheKey: String?) {
        fetchUrl(urlPath, fetchId: fetchId, context: nil, cacheKey: cacheKey, counter: 0)
    }

    private func fetchUrl(urlPath: String, fetchId: Int, context: Any?, cacheKey: String?) {
        fetchUrl(urlPath, fetchId: fetchId, context: context, cacheKey: cacheKey, counter: 0)
    }

    private func fetchUrl(urlPath: String, fetchId: Int, context: Any?, cacheKey: String?, counter: Int) {

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            if let result = self.getFromCache(cacheKey) {
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

                    let jsonResult:JSON
                    if (data == nil) {
                        jsonResult = JSON(NSNull())
                    } else {
                        jsonResult = JSON(data: data!)
                        //jsonResult.rawValue is NSNull, when data was not parseable. Don't cache it in that case
                        if (!(jsonResult.rawValue is NSNull) && error == nil && cacheKey != nil) {
                        self.cache.setObject(data!, forKey: cacheKey!)
                    }
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
    /* only use this if you know what you're doing
        we use it in TFCStationBase to get the name and coords of a station
        if it's not known yet */
    private func fetchUrlSync(urlPath: String, cacheKey: String?) -> JSON? {
        if let result = self.getFromCache(cacheKey) {
            NSLog("Sync fetch was still in cache")
            return result
        }
        let semaphore = dispatch_semaphore_create(0)
        let url: NSURL = NSURL(string: urlPath)!
        let absUrl = url.absoluteString
        NSLog("Start fetching sync data %@", absUrl)
        var jsonResult:JSON? = nil
        let session2 = TFCURLSession.sharedInstance.session
        let dataFetch: NSURLSessionDataTask? = session2.dataTaskWithURL(url, completionHandler: {data , response, error -> Void in

            NSLog("Task Sync completed")
            if(error != nil) {
                jsonResult = nil
            }
            if (data == nil) {
                jsonResult = JSON(NSNull())
            } else {
                jsonResult = JSON(data: data!)
                //jsonResult.rawValue is NSNull, when data was not parseable. Don't cache it in that case
                if (!(jsonResult!.rawValue is NSNull) && error == nil && cacheKey != nil) {
                    self.cache.setObject(data!, forKey: cacheKey!)
                }
            }
            dispatch_semaphore_signal(semaphore)

        })
        dataFetch?.resume()

        let timeout =  dispatch_time(DISPATCH_TIME_NOW, 5000000000) // 5 seconds
        if dispatch_semaphore_wait(semaphore, timeout) != 0 {
            NSLog("stationInfo sync call timed out.")
        }

        return jsonResult
    }

    private func getFromCache(cacheKey: String?) -> JSON? {
        if (cacheKey != nil && self.cache.objectForKey(cacheKey!) as? NSData != nil) {
            return JSON(data: self.cache.objectForKey(cacheKey!) as! NSData);
        }
        return nil;
    }
}

public protocol APIControllerProtocol: class {
    func didReceiveAPIResults(results: JSON?, error: NSError?, context: Any?)
}