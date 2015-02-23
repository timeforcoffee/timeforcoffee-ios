//
//  StationViewController
//  
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import UIKit

class StationViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, APIControllerProtocol {
    
    @IBOutlet weak var titleLabel: UINavigationItem!
    @IBOutlet var appsTableView : UITableView?
    var api : APIController?
    var refreshControl:UIRefreshControl!
    var departures = [Departure]()
    var station: Station?
    let kCellIdentifier: String = "DeparturesListCell"

    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.title = self.station?.name
        self.api = APIController(delegate: self)
        self.api?.getDepartures(self.station?.st_id!)
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.refreshControl = UIRefreshControl()
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.appsTableView?.addSubview(refreshControl)


    }
    
    func refresh(sender:AnyObject)
    {
        // Code to refresh table view
        self.api?.getDepartures(self.station?.st_id!)

    }

    
    func didReceiveAPIResults(results: JSONValue) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        self.refreshControl.endRefreshing()
        dispatch_async(dispatch_get_main_queue(), {
            self.departures = Departure.withJSON(results)
            self.appsTableView!.reloadData()
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        })
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.departures.count
    }
    
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier) as UITableViewCell
        
        let departure = self.departures[indexPath.row]
        cell.textLabel?.text = "\(departure.name) \(departure.to)"
/*        cell.imageView?.image = UIImage(named: "Blank52")*/
        var timeInterval: NSTimeInterval?
        var realtimeStr: String?
        var scheduledStr: String?
        
        if (departure.realtime != nil) {
            timeInterval = departure.realtime?.timeIntervalSinceNow
            realtimeStr = self.getShortDate(departure.realtime!)
        } else {
            timeInterval = departure.scheduled?.timeIntervalSinceNow
        }
        scheduledStr = self.getShortDate(departure.scheduled!)
        
        if (timeInterval != nil) {
            var timediff  = Int(ceil(timeInterval! / 60));
            if (timediff < 0) {
                timediff = 0;
            }
            if (departure.realtime != nil && departure.realtime != departure.scheduled) {
                cell.detailTextLabel?.text = "In \(timediff) minutes / \(realtimeStr!) / \(scheduledStr!)"
            } else {
                cell.detailTextLabel?.text = "In \(timediff) minutes / \(scheduledStr!)"
            }
        }
        
        cell.detailTextLabel?.text
        
        
        // Get the formatted price string for display in the subtitle
        //        let formattedPrice = album.price
        
        // Grab the artworkUrl60 key to get an image URL for the app's thumbnail
      /*  var urlString: String?
        urlString = nil
        if (urlString != nil) {
            // Check our image cache for the existing key. This is just a dictionary of UIImages
            var image = self.imageCache[urlString!]
            departure.imageURL = urlString
            
            if( image == nil ) {
                // If the image does not exist, we need to download it
                var imgURL: NSURL = NSURL(string: urlString!)!
                
                // Download an NSData representation of the image at the URL
                let request: NSURLRequest = NSURLRequest(URL: imgURL)
                NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue(), completionHandler: {(response: NSURLResponse!,data: NSData!,error: NSError!) -> Void in
                    if error == nil {
                        image = UIImage(data: data)
                        
                        // Store the image in to our cache
                        self.imageCache[urlString!] = image
                        if let cellToUpdate = tableView.cellForRowAtIndexPath(indexPath) {
                            
                            cellToUpdate.imageView?.image = image
                            self.fixWidthImage(cellToUpdate)
                        }
                    }
                    else {
                        println("Error: \(error.localizedDescription)")
                    }
                })
                
            }
            else {
                dispatch_async(dispatch_get_main_queue(), {
                    if let cellToUpdate = tableView.cellForRowAtIndexPath(indexPath) {
                        cellToUpdate.imageView?.image = image
                        self.fixWidthImage(cellToUpdate)
                    }
                })
            }
        }
*/
        
        return cell
        
    }
    
    func getShortDate(date:NSDate) -> String {
        let format = "HH:mm"
        var dateFmt = NSDateFormatter()
        dateFmt.timeZone = NSTimeZone.defaultTimeZone()
        dateFmt.dateFormat = format
        return dateFmt.stringFromDate(date)
    }

}
