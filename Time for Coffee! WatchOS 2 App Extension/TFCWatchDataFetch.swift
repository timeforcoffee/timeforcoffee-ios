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
    var lastDownload:[String:NSDate] = [:]
    var sessionRefreshTasks:[String:AnyObject] = [:]
    var validSessions:[String:Bool] = [:]

    public static let sharedInstance = TFCWatchDataFetch()

    override private init() {
        super.init()
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
            // if not older than 70 minutes
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
            DLog("finished WKApplicationRefreshBackgroundTask \(task) before barrier", toFile: true)
            dispatch_barrier_async(TFCWatchData.crunchQueue) {
                DLog("finished WKApplicationRefreshBackgroundTask \(task)", toFile: true)
                dispatch_async(dispatch_get_main_queue(), {
                    task.setTaskCompleted()
                })
            }
        }
        fetchDepartureData(handleReply)
    }

    public func fetchDepartureData(taskCallback:(() -> Void)? = nil) {
        let lastViewedStation = self.getLastViewedStation();

        func handleReply(stations: TFCStations?) {
            DLog("handleReply fetchDepartureData:", toFile: true)
            if let station = stations?.first {
                DLog("handleReply fetchDepartureData: \(station.name))", toFile: true)
                if let defaults = TFCDataStore.sharedInstance.getUserDefaults() {
                    // check if new station id and make it download complication, if so, later
                    let lastFirstStationId = defaults.stringForKey("lastFirstStationId")
                    if (lastFirstStationId != station.st_id) {
                        DLog("set lastFirstStationId to \(station.st_id) for \(station.name)", toFile: true)
                        defaults.setValue(station.st_id, forKey: "lastFirstStationId")
                        defaults.setObject(nil, forKey: "lastDepartureTime")
                        defaults.setObject(nil, forKey: "firstDepartureTime")
                        TFCDataStore.sharedInstance.getUserDefaults()?.setDouble(0.0, forKey: "backoffCount")

                    }
                }
                DLog("\(lastViewedStation?.st_id) != \(station.st_id)")
                if (watchdata.needsTimelineDataUpdate(station)) {
                    if (lastViewedStation?.st_id != station.st_id) {
                        self.fetchDepartureDataForStation(station)
                    }
                } else {
                    DLog("no timeline update needed", toFile: true)
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
            DLog("error \(error)", toFile: true)
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
        self.watchdata.startCrunchQueue {
            //this could be called before DB is setup, so wait, if that's the case..
            dispatch_group_wait(TFCDataStore.sharedInstance.myCoreDataStackSetupGroup, dispatch_time(DISPATCH_TIME_NOW, Int64(15.0 * Double(NSEC_PER_SEC))))

            if lastViewedStation != nil {
                self.fetchDepartureDataForStation(lastViewedStation!)
            }
            DLog("call getStations", toFile: true)
            TFCDataStore.sharedInstance.watchdata.getStations(handleReply, errorReply: errorReply, stopWithFavorites: true)
        }


    }

    public func fetchDepartureDataForStation(station:TFCStation) {
        if let downloadingSince = self.downloading[station.st_id]  {
            //if downloading since less than 30 secs. don't again.
            if downloadingSince.dateByAddingTimeInterval(30) > NSDate() {
                DLog("Station \(station.st_id) is already downloading since \(downloadingSince)", toFile: true)
                return
            }
        }
        self.downloading[station.st_id] = NSDate()
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
        if let id = backgroundConfigObject.identifier {
            self.validSessions[id] = true
            DLog("Starting download task \(id)")
        }
        downloadTask.resume()

    }


    @available(watchOSApplicationExtension 3.0, *)
    public func rejoinURLSession(urlTask: WKURLSessionRefreshBackgroundTask) {
        let backgroundConfigObject = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(urlTask.sessionIdentifier)
        let backgroundSession = NSURLSession(configuration: backgroundConfigObject, delegate: self, delegateQueue: nil)
        self.sessionRefreshTasks[urlTask.sessionIdentifier] = urlTask
        let st_id = backgroundSession.configuration.identifier
        DLog("Rejoining session \(urlTask.sessionIdentifier) for id \(st_id)", toFile: true)
        if  !(self.validSessions[urlTask.sessionIdentifier] == true) {
            self.completeTask(urlTask.sessionIdentifier)
        }
    }

    private func handleURLSession(fileContent:NSData?, st_id: String, sess_id: String? ) {
        let station = TFCStation.initWithCacheId(st_id)
        //let fileContent = try? NSString(contentsOfURL: location, encoding: NSUTF8StringEncoding)
        if let fileContent = fileContent {
            let  data = JSON(data: fileContent)
            station.didReceiveAPIResults(data, error: nil, context: nil)
            let isActive:Bool
            if #available(watchOSApplicationExtension 3.0, *) {
                isActive = (WKExtension.sharedExtension().applicationState == .Active)
            } else {
                isActive = false
            }

            if (st_id == self.getLastViewedStation()?.st_id  && isActive) {
                DLog("notification TFCWatchkitUpdateCurrentStation")
                NSNotificationCenter.defaultCenter().postNotificationName("TFCWatchkitUpdateCurrentStation", object: nil, userInfo: nil)
            }
            // check if we fetched the one in the complication and then update it
            if let defaults = TFCDataStore.sharedInstance.getUserDefaults() {
                DLog("\(st_id) == \(defaults.stringForKey("lastFirstStationId"))", toFile: true)
                if (st_id == defaults.stringForKey("lastFirstStationId")) {
                    if (CLKComplicationServer.sharedInstance().activeComplications?.count > 0) {
                        if self.watchdata.needsTimelineDataUpdate(station) {
                            DLog("updateComplicationData", toFile: true)
                            self.watchdata.updateComplicationData()
                        }
                    }
                    if let departures = station.getFilteredDepartures() {
                        defaults.setObject(departures.first?.getScheduledTimeAsNSDate(), forKey: "firstDepartureTime")
                    } else {
                        defaults.setObject(nil, forKey: "firstDepartureTime")
                    }
                }
            }
        } else {
            DLog("fileContent was nil", toFile: true)
        }

        if let sessID = sess_id {
            self.completeTask(sessID)
        }
        DLog("remaining tasks: \(self.sessionRefreshTasks.count)")
    }



    private func completeTask(sessID: String) {
        if #available(watchOSApplicationExtension 3.0, *) {
            dispatch_barrier_async(TFCWatchData.crunchQueue, {
            if let task = self.sessionRefreshTasks[sessID] as? WKURLSessionRefreshBackgroundTask {
                DLog("finished WKURLSessionRefreshBackgroundTask part 1 \(sessID)", toFile: true)
                DLog("was: \(task) part 2 \(sessID)", toFile: true)
                dispatch_async(dispatch_get_main_queue(), {
                    task.setTaskCompleted()
                })
                self.sessionRefreshTasks.removeValueForKey(sessID)
                }
            })
        }
    }

    public func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
       // DLog("Did download \(downloadTask.taskDescription) to \(location)", toFile: true)
        let fileContent = NSData(contentsOfURL: location)
        if let st_id = downloadTask.taskDescription {
            if let start = self.downloading[st_id] {
                let time = NSDate().timeIntervalSince1970 - start.timeIntervalSince1970
                DLog("Download of \(st_id) took \(time) seconds. task: \(session.configuration.identifier) ", toFile: true)
            }
            if let lastDownload = lastDownload[st_id] {
                if (lastDownload.dateByAddingTimeInterval(3) > NSDate()) {
                    DLog("last download was just less than 3 seconds ago. Don't start the queue for processing")
                    return
                }

            }
            lastDownload[st_id] = NSDate()
            DLog("task: \(session.configuration.identifier)", toFile: true)
            self.watchdata.startCrunchQueue {
                DLog("crunchQueue start didFinishDownloadingToURL \(st_id) \(session.configuration.identifier) ")
                self.handleURLSession(fileContent, st_id: st_id, sess_id: session.configuration.identifier)
                SendLogs2Phone()
                DLog("crunchQueue end   didFinishDownloadingToURL \(st_id) \(session.configuration.identifier) ")

            }
        }
    }

    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        DLog(" didCompleteWithError before crunchQueue \(task.taskDescription)")

        self.watchdata.startCrunchQueue {
            DLog("crunchQueue start didCompleteWithError \(task.taskDescription)")

            DLog("URLSession didComplete \(task.taskDescription) task: \(session.configuration.identifier) error: \(error)", toFile: true)
            TFCDataStore.sharedInstance.watchdata.scheduleNextUpdate()
            if let st_id = task.taskDescription {
                self.downloading.removeValueForKey(st_id)
            }
            if let sessID = session.configuration.identifier {
                self.completeTask(sessID)
            }

            session.finishTasksAndInvalidate()
            DLog("crunchQueue end   didCompleteWithError \(task.taskDescription)")

        }
    }

    public func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession) {
        DLog("URLSessionDidFinishEventsForBackgroundURLSession \(session.configuration.identifier)", toFile: true)
    }

    public func URLSession(session: NSURLSession, didBecomeInvalidWithError error: NSError?) {
        if let id = session.configuration.identifier {
            self.validSessions.removeValueForKey(id)
        }
        DLog("URLSession didBecomeInvalidWithError \(session.configuration.identifier) error: \(error)", toFile: true)

    }
}

