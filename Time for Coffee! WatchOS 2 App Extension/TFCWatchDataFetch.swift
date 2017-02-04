//
//  TFCFetchData.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 09.09.16.
//  Copyright © 2016 opendata.ch. All rights reserved.
//

import Foundation
import WatchKit

open class TFCWatchDataFetch: NSObject, URLSessionDownloadDelegate {

    var downloading:[String:Date] = [:]
    var lastDownload:[String:Date] = [:]
    var sessionRefreshTasks:[String:AnyObject] = [:]
    var validSessions:[String:Bool] = [:]

    open static let sharedInstance = TFCWatchDataFetch()

    override fileprivate init() {
        super.init()
    }

    open func setLastViewedStation(_ station: TFCStation?) {
        TFCDataStore.sharedInstance.getUserDefaults()?.set(station?.st_id, forKey: "lastViewedStationId")
        TFCDataStore.sharedInstance.getUserDefaults()?.set(Date(), forKey: "lastViewedStationDate")
    }

    lazy var watchdata: TFCWatchData = {
        return TFCWatchData()
    }()


    func getLastViewedStation() -> TFCStation? {
        let defaults = TFCDataStore.sharedInstance.getUserDefaults()
        if let date = defaults?.object(forKey: "lastViewedStationDate") as? Date {
            // if not older than 50 minutes
            if date.addingTimeInterval(50 * 60) > Date() {
                if let stationId =  defaults?.object(forKey: "lastViewedStationId") as? String {
                    return TFCStation.initWithCacheId(stationId)
                }
            }
        }
        return nil
    }

    open func fetchDepartureData(task: WKApplicationRefreshBackgroundTask) {
        func handleReply() {
            //DLog("finished WKApplicationRefreshBackgroundTask \(task) before barrier", toFile: true)
            TFCWatchData.crunchQueue.async(flags: .barrier, execute: {
                DLog("finished WKApplicationRefreshBackgroundTask \(task)", toFile: true)
                DispatchQueue.main.async(execute: {
                    task.setTaskCompleted()
                })
            }) 
        }
        fetchDepartureData(handleReply)
    }

    open func fetchDepartureData(_ taskCallback:(() -> Void)? = nil) {
        DispatchQueue.global(qos: .utility).async {
            let lastViewedStation = self.getLastViewedStation();

            func handleReply(_ stations: TFCStations?) {
                //DLog("handleReply fetchDepartureData:", toFile: true)
                if let station = stations?.getStation(0) {
                    DLog("handleReply fetchDepartureData: \(station.name))", toFile: true)
                    if let defaults = TFCDataStore.sharedInstance.getUserDefaults() {
                        // check if new station id and make it download complication, if so, later
                        let lastFirstStationId = defaults.string(forKey: "lastFirstStationId")
                        if (lastFirstStationId != station.st_id) {
                            DLog("set lastFirstStationId to \(station.st_id) for \(station.name)", toFile: true)
                            defaults.setValue(station.st_id, forKey: "lastFirstStationId")
                            defaults.set(nil, forKey: "lastDepartureTime")
                            defaults.set(nil, forKey: "firstDepartureTime")
                            TFCDataStore.sharedInstance.getUserDefaults()?.set(0.0, forKey: "backoffCount")

                        }
                    }
                    DLog("\(String(describing: lastViewedStation?.st_id)) != \(station.st_id)")
                    if (self.watchdata.needsTimelineDataUpdate(station)) {
                        if (lastViewedStation?.st_id != station.st_id) {
                            self.fetchDepartureDataForStation(station)
                        }
                    } else {
                        DLog("no timeline update needed", toFile: true)
                    }
                } else {
                    DLog("backoff: No station set", toFile: true)
                    // try again in 5 minutes
                    WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: self.watchdata.getBackOffTime() , userInfo: nil) { (error) in
                        if error == nil {
                            //successful
                        }
                    }
                }
                taskCallback?()
            }
            func errorReply(_ error: String) {
                DLog("backoff: error \(error)", toFile: true)
                // try again in 5 minutes
                WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: self.watchdata.getBackOffTime(), userInfo: nil) { (error) in
                    if error == nil {
                        //successful
                    }
                }
                taskCallback?()
            }
            if lastViewedStation != nil {
                self.fetchDepartureDataForStation(lastViewedStation!)
            }
            self.watchdata.startCrunchQueue {
                DLog("call getStations", toFile: true)
                TFCDataStore.sharedInstance.watchdata.getStations(handleReply, errorReply: errorReply, stopWithFavorites: true)
            }
        }
    }

    open func fetchDepartureDataForStation(_ station:TFCStation) {
        if let downloadingSince = self.downloading[station.st_id]  {
            //if downloading since less than 30 secs. don't again.
            if downloadingSince.addingTimeInterval(30) > Date() {
                DLog("Station \(station.st_id) is already downloading since \(downloadingSince)", toFile: true)
                return
            }
        }
        self.downloading[station.st_id] = Date()
        let sampleDownloadURL = URL(string: station.getDeparturesURL())!
        DLog("Download \(sampleDownloadURL)", toFile: true)

        let backgroundConfigObject = URLSessionConfiguration.background(withIdentifier: (UUID().uuidString))
        backgroundConfigObject.requestCachePolicy = .useProtocolCachePolicy

        if let uid = TFCDataStore.sharedInstance.getTFCID() {
            backgroundConfigObject.httpAdditionalHeaders = ["TFCID": uid]
        }

        let backgroundSession = Foundation.URLSession(configuration: backgroundConfigObject, delegate: self, delegateQueue: nil)

        backgroundConfigObject.sessionSendsLaunchEvents = true

        let downloadTask = backgroundSession.downloadTask(with: sampleDownloadURL)

        downloadTask.taskDescription = station.st_id
        if WKExtension.shared().applicationState == .active {
            downloadTask.priority = 1.0
        }
        if let id = backgroundConfigObject.identifier {
            self.validSessions[id] = true
            DLog("Starting download task \(id)")
        }
        downloadTask.resume()

    }

    open func rejoinURLSession(_ urlTask: WKURLSessionRefreshBackgroundTask) {
        let backgroundConfigObject = URLSessionConfiguration.background(withIdentifier: urlTask.sessionIdentifier)
        let backgroundSession = Foundation.URLSession(configuration: backgroundConfigObject, delegate: self, delegateQueue: nil)
        self.sessionRefreshTasks[urlTask.sessionIdentifier] = urlTask
        let st_id = backgroundSession.configuration.identifier
        DLog("Rejoining session \(urlTask.sessionIdentifier) for id \(String(describing: st_id))", toFile: true)
        if  !(self.validSessions[urlTask.sessionIdentifier] == true) {
            self.completeTask(urlTask.sessionIdentifier)
        }
    }

    fileprivate func handleURLSession(_ fileContent:Data?, st_id: String, sess_id: String? ) {
        //let fileContent = try? NSString(contentsOfURL: location, encoding: NSUTF8StringEncoding)
        if let fileContent = fileContent {
            if let station = TFCStation.initWithCacheId(st_id) {
                let  data = JSON(data: fileContent)
                station.didReceiveAPIResults(data, error: nil, context: nil)
                let isActive:Bool
                isActive = (WKExtension.shared().applicationState == .active)
                if (st_id == self.getLastViewedStation()?.st_id  && isActive) {
                    DLog("notification TFCWatchkitUpdateCurrentStation")
                    NotificationCenter.default.post(name: Notification.Name(rawValue: "TFCWatchkitUpdateCurrentStation"), object: nil, userInfo: nil)
                }
                // check if we fetched the one in the complication and then update it
                if let defaults = TFCDataStore.sharedInstance.getUserDefaults() {
                    DLog("\(st_id) == \(String(describing: defaults.string(forKey: "lastFirstStationId") ?? nil))", toFile: true)
                    if (st_id == defaults.string(forKey: "lastFirstStationId")) {
                        if let c = CLKComplicationServer.sharedInstance().activeComplications?.count, c > 0 {
                            if self.watchdata.needsTimelineDataUpdate(station) {
                                DLog("updateComplicationData", toFile: true)
                                self.watchdata.updateComplicationData()
                            }
                        }
                        if let departures = station.getFilteredDepartures() {
                            defaults.set(departures.first?.getScheduledTimeAsNSDate(), forKey: "firstDepartureTime")
                        } else {
                            defaults.set(nil, forKey: "firstDepartureTime")
                        }
                    }
                }
            }
        } else {
            DLog("fileContent was nil", toFile: true)
        }

        if let sessID = sess_id {
            self.completeTask(sessID)
        }
      //  DLog("remaining tasks: \(self.sessionRefreshTasks.count)")
    }



    fileprivate func completeTask(_ sessID: String) {
        TFCWatchData.crunchQueue.async(flags: .barrier, execute: {
            if let task = self.sessionRefreshTasks[sessID] as? WKURLSessionRefreshBackgroundTask {
                DLog("finished WKURLSessionRefreshBackgroundTask part 1 \(sessID)", toFile: true)
                //DLog("was: \(task) part 2 \(sessID)", toFile: true)
                DispatchQueue.main.async(execute: {
                    task.setTaskCompleted()
                })
                self.sessionRefreshTasks.removeValue(forKey: sessID)
            }
        })
    }

    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
       // DLog("Did download \(downloadTask.taskDescription) to \(location)", toFile: true)
        let fileContent = try? Data(contentsOf: location)
        if let st_id = downloadTask.taskDescription {
            if let start = self.downloading[st_id] {
                let time = Date().timeIntervalSince1970 - start.timeIntervalSince1970
                DLog("Download of \(st_id) took \(time) seconds. task: \(String(describing: session.configuration.identifier)) ", toFile: true)
            }
            if let lastDownload = lastDownload[st_id] {
                if (lastDownload.addingTimeInterval(3) > Date()) {
                    DLog("last download was just less than 3 seconds ago. Don't start the queue for processing")
                    return
                }

            }
            lastDownload[st_id] = Date()
          //  DLog("task: \(String(describing: session.configuration.identifier))", toFile: true)
            self.watchdata.startCrunchQueue {
                //DLog("crunchQueue start didFinishDownloadingToURL \(st_id) \(String(describing: session.configuration.identifier)) ")
                self.handleURLSession(fileContent, st_id: st_id, sess_id: session.configuration.identifier)
                DLog("crunchQueue end   didFinishDownloadingToURL \(st_id) \(String(describing: session.configuration.identifier)) ")

            }
        }
    }

    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
       // DLog(" didCompleteWithError before crunchQueue \(String(describing: task.taskDescription))")

        self.watchdata.startCrunchQueue {
          //  DLog("crunchQueue start didCompleteWithError \(String(describing: task.taskDescription))")

            DLog("URLSession didComplete \(String(describing: task.taskDescription)) task: \(String(describing: session.configuration.identifier)) error: \(String(describing: error))", toFile: true)
            TFCDataStore.sharedInstance.watchdata.scheduleNextUpdate()
            if let st_id = task.taskDescription {
                self.downloading.removeValue(forKey: st_id)
            }
            if let sessID = session.configuration.identifier {
                self.completeTask(sessID)
            }

            session.finishTasksAndInvalidate()
            //DLog("crunchQueue end   didCompleteWithError \(String(describing: task.taskDescription))")

        }
    }

    open func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DLog("URLSessionDidFinishEventsForBackgroundURLSession \(String(describing: session.configuration.identifier))", toFile: true)
    }

    open func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let id = session.configuration.identifier {
            self.validSessions.removeValue(forKey: id)
        }
        DLog("URLSession didBecomeInvalidWithError \(String(describing: session.configuration.identifier)) error: \(String(describing: error))", toFile: true)

    }
}

