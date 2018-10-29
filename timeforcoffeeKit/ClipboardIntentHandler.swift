//
//  NextDeparturesIntentHandler.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 21.09.18.
//  Copyright © 2018 opendata.ch. All rights reserved.
//

import Foundation


@available(iOSApplicationExtension 12.0, *)
@available(watchOSApplicationExtension 5.0, *)
public class ClipboardIntentHandler: NSObject, ClipboardIntentHandling {
    
    public override init() {
        super.init()
    }
    
    deinit {
        DLog("Deinit")
    }
    
    public func confirm(intent: ClipboardIntent, completion: @escaping (ClipboardIntentResponse) -> Void) {
        completion(ClipboardIntentResponse(code: .ready, userActivity: nil))
    }
    
  
    
    fileprivate func callMethod(_ cb: TFCXCallback, _ queryStrings: [String : String], _ completion: @escaping (ClipboardIntentResponse) -> Void) {
        cb.handleCall(queryStrings:queryStrings) { (error: String?, params: [String:String?]) in
            //replace ? in the beginning
            if let error = error {
                UIPasteboard.general.string = error
                completion(ClipboardIntentResponse(code: .failure, userActivity: nil))
                return
            }
            //UIPasteboard.general.string = url?.absoluteString.replace("^\\?", template: "").removingPercentEncoding
            let encoder = JSONEncoder()
            do {
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(params)
                UIPasteboard.general.string = String(data:data, encoding: .utf8)
            } catch _ {
                UIPasteboard.general.string = "{}"
            }
            //UIPasteboard.general.setValue(params, forPasteboardType: "ch.opendata.timeforcoffee.dictionary")
            completion(ClipboardIntentResponse(code: .success, userActivity: nil))
            
        }
    }
    
    public func handle(intent: ClipboardIntent, completion: @escaping (ClipboardIntentResponse) -> Void) {
        
        #if !os(watchOS)
        let cb = TFCXCallback()
        let pasteBoardString = UIPasteboard.general.string
        DLog("from Pasteboard: \(String(describing: pasteBoardString))")
        if let pasteBoardString = pasteBoardString {
            var queryStrings:[String:String] = [:]
            if pasteBoardString.starts(with: "timeforcoffee://"), let url = URL(string: pasteBoardString) {
                queryStrings = TFCXCallback.getQueryParameters(url)
                if queryStrings["method"] == nil {
                    queryStrings["method"] = url.path
                }
            }  else if (pasteBoardString.starts(with: "{")){
                TFCXCallback.fillParametersFromDict(pasteBoardString, &queryStrings)
            }
            callMethod(cb, queryStrings, completion)
        } else {
            callMethod(cb, [:], completion)
        }
        return
        
        
        #else
        completion(ClipboardIntentResponse(code: .failure, userActivity: nil))
        #endif

    
    }
    
    
}

