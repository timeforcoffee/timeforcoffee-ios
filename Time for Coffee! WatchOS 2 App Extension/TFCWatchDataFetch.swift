//
//  TFCFetchData.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 09.09.16.
//  Copyright © 2016 opendata.ch. All rights reserved.
//

import Foundation
import WatchKit


public class TFCWatchDataFetch: NSObject, NSURLSessionDownloadDelegate {

    var downloading:[String:Bool] = [:]

    public class var sharedInstance: TFCWatchDataFetch {
        struct Static {
            static let instance: TFCWatchDataFetch = TFCWatchDataFetch()
        }
        return Static.instance
    }

    public func setLastViewedStation(station: TFCStation?) {
        TFCDataStore.sharedInstance.getUserDefaults()?.setObject(station?.st_id, forKey: "lastViewedStationId")
        TFCDataStore.sharedInstance.getUserDefaults()?.setObject(NSDate(), forKey: "lastViewedStationDate")
    }

    lazy var watchdata: TFCWatchData = {
        return TFCWatchData()
    }()


    func getLastViewedStation() -> TFCStation? {
        let defaults = TFCDataStore.sharedInstance.getUserDefaults()
        if let date = defaults?.objectForKey("lastViewedStationDate") as? NSDate {
            // if not older than 70 minuts
            if date.dateByAddingTimeInterval(70 * 60) > NSDate() {
                if let stationId =  defaults?.objectForKey("lastViewedStationId") as? String {
                    return TFCStation.initWithCacheId(stationId)
                }
            }
        }
        return nil
    }

    public func fetchDepartureData(task: WKApplicationRefreshBackgroundTask? = nil) {
        let lastViewedStation = self.getLastViewedStation();

        func handleReply(stations: TFCStations?) {
            DLog("handleReply")
            if let station = stations?.first {
                DLog("\(lastViewedStation?.st_id) != \(station.st_id)")
                if (lastViewedStation?.st_id != station.st_id) {
                    self.fetchDepartureDataForStation(station)
                }
            } else {
                DLog("No station set", toFile: true)
                // try again in 5 minutes
                WKExtension.sharedExtension().scheduleBackgroundRefreshWithPreferredDate(watchdata.getBackOffTime() , userInfo: nil) { (error) in
                    if error == nil {
                        //successful
                    }
                }
            }
            task?.setTaskCompleted()
        }
        func errorReply(error: String) {
            DLog("error \(error)")
            // try again in 5 minutes
            WKExtension.sharedExtension().scheduleBackgroundRefreshWithPreferredDate(watchdata.getBackOffTime(), userInfo: nil) { (error) in
                if error == nil {
                    //successful
                }
            }
            task?.setTaskCompleted()
        }
        if lastViewedStation != nil {
            fetchDepartureDataForStation(lastViewedStation!)
        }
        TFCDataStore.sharedInstance.watchdata.getStations(handleReply, errorReply: errorReply, stopWithFavorites: true)

    }

    public func fetchDepartureDataForStation(station:TFCStation) {
        if ( downloading[station.st_id] == true) {
            DLog("Station \(station.st_id) is already downloading", toFile: true)
            return
        }
        downloading[station.st_id] = true
        let sampleDownloadURL = NSURL(string: station.getDeparturesURL())!
        DLog("Download \(sampleDownloadURL)", toFile: true)

        let backgroundConfigObject:NSURLSessionConfiguration
        if (WKExtension.sharedExtension().applicationState == .Background) {
            DLog("applicationState: Background")
            backgroundConfigObject = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier((NSUUID().UUIDString))
        } else {
            DLog("applicationState: Not Background")
            backgroundConfigObject = NSURLSessionConfiguration.defaultSessionConfiguration()
        }
        backgroundConfigObject.requestCachePolicy = .UseProtocolCachePolicy
        let backgroundSession = NSURLSession(configuration: backgroundConfigObject, delegate: self, delegateQueue: nil)

        backgroundConfigObject.sessionSendsLaunchEvents = true

        let downloadTask = backgroundSession.downloadTaskWithURL(sampleDownloadURL)
        downloadTask.taskDescription = station.st_id
        if WKExtension.sharedExtension().applicationState == .Active {
            downloadTask.priority = 1.0
        }
        downloadTask.resume()
    }


    public func rejoinURLSession(urlTask: WKURLSessionRefreshBackgroundTask) {
        let backgroundConfigObject = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(urlTask.sessionIdentifier)
        let backgroundSession = NSURLSession(configuration: backgroundConfigObject, delegate: self, delegateQueue: nil)
        DLog("Rejoining session \(urlTask.sessionIdentifier) \(backgroundSession)", toFile: true)

    }

    public func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        DLog("downloaded \(downloadTask.taskDescription) to \(location)", toFile: true)
        if let st_id = downloadTask.taskDescription {
            let station = TFCStation.initWithCacheId(st_id)
            //let fileContent = try? NSString(contentsOfURL: location, encoding: NSUTF8StringEncoding)
            if let fileContent = NSData(contentsOfURL: location){
                let  data = JSON(data: fileContent)
                station.didReceiveAPIResults(data, error: nil, context: nil)
                if st_id == self.getLastViewedStation()?.st_id {
                    NSNotificationCenter.defaultCenter().postNotificationName("TFCWatchkitUpdateCurrentStation", object: nil, userInfo: nil)
                }
                // check if we fetched the one in the complication and then update it
                if (CLKComplicationServer.sharedInstance().activeComplications?.count > 0) {
                    if (st_id == NSUserDefaults(suiteName: "group.ch.opendata.timeforcoffee")?.stringForKey("lastFirstStationId")) {
                        if watchdata.needsTimelineDataUpdate(station) {
                            DLog("updateComplicationData", toFile: true)
                            watchdata.updateComplicationData()
                        }
                    }
                }
            }
        }
    }

    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        DLog("didCompleteWithError \(error)")
        TFCDataStore.sharedInstance.watchdata.scheduleNextUpdate()
        if let st_id = task.taskDescription {
            downloading[st_id] = nil
        }
        session.finishTasksAndInvalidate()
    }
}

