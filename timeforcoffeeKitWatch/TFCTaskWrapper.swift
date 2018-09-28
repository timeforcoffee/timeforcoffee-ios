//
//  TFCTaskWrapper.swift
//  timeforcoffeeKitWatch
//
//  Created by Christian Stocker on 27.09.18.
//  Copyright © 2018 opendata.ch. All rights reserved.
//

import Foundation
import WatchKit
open class TFCTaskWrapper {
    
    fileprivate let task:WKRefreshBackgroundTask
    var completed:Bool = false
    
    public init(_ task:WKRefreshBackgroundTask) {
        self.task = task
    }
    
    open func getTask() -> WKRefreshBackgroundTask {
        return self.task
    }
    
    open func getHash() -> Int {
        return self.task.hash
    }
    
    open func isCompleted() -> Bool {
        return self.completed
    }
    
    open func setAsCompleted() {
        self.completed = true
    }
    
    func setTaskCompleted() {
        self.completed = true
        if #available(watchOSApplicationExtension 4.0, *) {
            task.setTaskCompletedWithSnapshot(false)
        } else {
            task.setTaskCompleted()
        }
    }
    open func setTaskCompletedAndClear(callback:(() -> Bool)? = nil) {
        if self.isCompleted() == false {
            DLog("runningTasks: Set Task completed for \(self.getHash())")
            if let callback = callback {
                DispatchQueue.main.async(execute: {
                    if callback() {
                        self.setAsCompleted()
                    }
                })
                return
            }
            DispatchQueue.main.async(execute: {
                self.task.setTaskCompleted()
            })
            return
        }
        DLog("runningTasks: Already called \(self.getHash()) before. Not call taskCompleted.")
    }
}
