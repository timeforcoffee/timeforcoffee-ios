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

    var downloading:[String:NSDate] = [:]
    var sessionRefreshTasks:[String:AnyObject] = [:]

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
    @available(watchOSApplicationExtension 3.0, *)
    public func fetchDepartureData(task task: WKApplicationRefreshBackgroundTask) {
        func handleReply() {
            DLog("WKApplicationRefreshBackgroundTask finished", toFile: true)
            task.setTaskCompleted()
        }
        fetchDepartureData(handleReply)
    }

    public func fetchDepartureData(taskCallback:(() -> Void)? = nil) {
        let lastViewedStation = self.getLastViewedStation();

        func handleReply(stations: TFCStations?) {
            DLog("handleReply")
            if let station = stations?.first {
                if let defaults = TFCDataStore.sharedInstance.getUserDefaults() {
                    // check if new station id and make it download complication, if so, later
                    let lastFirstStationId = defaults.stringForKey("lastFirstStationId")
                    if (lastFirstStationId != station.st_id) {
                        defaults.setValue(station.st_id, forKey: "lastFirstStationId")
                        defaults.setObject(nil, forKey: "lastDepartureTime")
                        defaults.setObject(nil, forKey: "firstDepartureTime")
                    }
                }
                DLog("\(lastViewedStation?.st_id) != \(station.st_id)")
                if (lastViewedStation?.st_id != station.st_id) {
                    self.fetchDepartureDataForStation(station)
                }
            } else {
                DLog("No station set", toFile: true)
                // try again in 5 minutes
                if #available(watchOSApplicationExtension 3.0, *) {
                    WKExtension.sharedExtension().scheduleBackgroundRefreshWithPreferredDate(watchdata.getBackOffTime() , userInfo: nil) { (error) in
                        if error == nil {
                            //successful
                        }
                    }
                }
            }
            taskCallback?()
        }
        func errorReply(error: String) {
            DLog("error \(error)")
            // try again in 5 minutes
            if #available(watchOSApplicationExtension 3.0, *) {
                WKExtension.sharedExtension().scheduleBackgroundRefreshWithPreferredDate(watchdata.getBackOffTime(), userInfo: nil) { (error) in
                    if error == nil {
                        //successful
                    }
                }
            }
            taskCallback?()
        }
        if lastViewedStation != nil {
            fetchDepartureDataForStation(lastViewedStation!)
        }
        TFCDataStore.sharedInstance.watchdata.getStations(handleReply, errorReply: errorReply, stopWithFavorites: true)

    }

    public func fetchDepartureDataForStation(station:TFCStation) {
        if let downloadingSince = downloading[station.st_id]  {
            //if downloading since less than 30 secs. don't again.
            if downloadingSince.dateByAddingTimeInterval(30) > NSDate() {
                DLog("Station \(station.st_id) is already downloading since \(NSDate())", toFile: true)
                return
            }
        }
        downloading[station.st_id] = NSDate()
        let sampleDownloadURL = NSURL(string: station.getDeparturesURL())!
        DLog("Download \(sampleDownloadURL)", toFile: true)

        let backgroundConfigObject:NSURLSessionConfiguration
        if #available(watchOSApplicationExtension 3.0, *) {
            backgroundConfigObject = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier((NSUUID().UUIDString))
        } else {
            backgroundConfigObject = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier((NSUUID().UUIDString))
        }
        backgroundConfigObject.requestCachePolicy = .UseProtocolCachePolicy
        let backgroundSession = NSURLSession(configuration: backgroundConfigObject, delegate: self, delegateQueue: nil)

        backgroundConfigObject.sessionSendsLaunchEvents = true

        let downloadTask = backgroundSession.downloadTaskWithURL(sampleDownloadURL)

        downloadTask.taskDescription = station.st_id
        if #available(watchOSApplicationExtension 3.0, *) {
            if WKExtension.sharedExtension().applicationState == .Active {
                downloadTask.priority = 1.0
            }
        }
        downloadTask.resume()
    }


    @available(watchOSApplicationExtension 3.0, *)
    public func rejoinURLSession(urlTask: WKURLSessionRefreshBackgroundTask) {
        let backgroundConfigObject = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(urlTask.sessionIdentifier)
        let backgroundSession = NSURLSession(configuration: backgroundConfigObject, delegate: self, delegateQueue: nil)
        self.sessionRefreshTasks[urlTask.sessionIdentifier] = urlTask
        DLog("Rejoining session \(urlTask.sessionIdentifier) \(backgroundSession)", toFile: true)
    }

    public func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        DLog("downloaded \(downloadTask.taskDescription) to \(location)", toFile: true)
        if let st_id = downloadTask.taskDescription {
            if let start = downloading[st_id] {
                let time = NSDate().timeIntervalSince1970 - start.timeIntervalSince1970
                DLog("Download of \(st_id) took \(time) seconds", toFile: true)
                DLog("task \(session.configuration.identifier)", toFile: true)
            }
            let station = TFCStation.initWithCacheId(st_id)
            //let fileContent = try? NSString(contentsOfURL: location, encoding: NSUTF8StringEncoding)
            if let fileContent = NSData(contentsOfURL: location){
                let  data = JSON(data: fileContent)
                station.didReceiveAPIResults(data, error: nil, context: nil)
                if st_id == self.getLastViewedStation()?.st_id {
                    NSNotificationCenter.defaultCenter().postNotificationName("TFCWatchkitUpdateCurrentStation", object: nil, userInfo: nil)
                }
                // check if we fetched the one in the complication and then update it
                if let defaults = TFCDataStore.sharedInstance.getUserDefaults() {
                    if (st_id == defaults.stringForKey("lastFirstStationId")) {
                        if (CLKComplicationServer.sharedInstance().activeComplications?.count > 0) {
                            if watchdata.needsTimelineDataUpdate(station) {
                                DLog("updateComplicationData", toFile: true)
                                watchdata.updateComplicationData()
                            }
                        }
                        if let departures = station.getFilteredDepartures() {
                            defaults.setObject(departures.last?.getScheduledTimeAsNSDate(), forKey: "lastDepartureTime")
                            defaults.setObject(departures.first?.getScheduledTimeAsNSDate(), forKey: "firstDepartureTime")
                        } else {
                            defaults.setObject(nil, forKey: "lastDepartureTime")
                            defaults.setObject(nil, forKey: "firstDepartureTime")
                        }
                    }
                }
            }

            if #available(watchOSApplicationExtension 3.0, *) {
                if let sessID = session.configuration.identifier {
                    if let task = sessionRefreshTasks[sessID] as? WKURLSessionRefreshBackgroundTask {
                        task.setTaskCompleted()
                        DLog("WKURLSessionRefreshBackgroundTask \(sessID) finished", toFile: true)
                        sessionRefreshTasks.removeValueForKey(sessID)
                    }
                }
            }
        }
    }

    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        DLog("URLSession didComplete \(task.taskDescription) error: \(error)", toFile: true)
        TFCDataStore.sharedInstance.watchdata.scheduleNextUpdate()
        if let st_id = task.taskDescription {
            downloading.removeValueForKey(st_id)
        }
        session.finishTasksAndInvalidate()
    }
}

