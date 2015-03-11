//
//  StationViewController
//
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import UIKit
import timeforcoffeeKit
import MapKit

class DeparturesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate, APIControllerProtocol, MGSwipeTableCellDelegate, MKMapViewDelegate {

    @IBOutlet weak var titleLabel: UINavigationItem!
    @IBOutlet var appsTableView : UITableView?
    var api : APIController?
    var refreshControl:UIRefreshControl!
    var departures: [TFCDeparture]?
    var station: TFCStation?
    var networkErrorMsg: String?
    let kCellIdentifier: String = "DeparturesListCell"
    var gestureRecognizer: UIGestureRecognizerDelegate?
    var mapSwipeUpStart: CGFloat?
    var destinationPlacemark: MKPlacemark?
    var startHeight: CGFloat!
    
    @IBOutlet weak var stationIconView: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var BackButton: UIButton!

    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var gradientView: UIImageView!
    @IBOutlet weak var borderBottomView: UIView!

    @IBOutlet weak var navBarImage: UIImageView!

    @IBOutlet weak var navBarView: UIView!

    @IBOutlet weak var releaseToViewLabel: UILabel!

    @IBAction func BackButtonClicked(sender: UIButton) {
        self.navigationController?.popViewControllerAnimated(true)
    }

    @IBOutlet weak var topBarHeight: NSLayoutConstraint!

    @IBOutlet weak var mapHeight: NSLayoutConstraint!

    @IBAction func panOnTopView(sender: UIPanGestureRecognizer) {
        let location = sender.locationInView(self.topView)
        let releasePoint = CGFloat(200.0)
        var topBarCalculatedHeight = startHeight + (location.y - startHeight) / 3

        if (mapSwipeUpStart != nil) {
            topBarCalculatedHeight = location.y + mapSwipeUpStart!
        }

        if (topBarCalculatedHeight < startHeight) {
            topBarCalculatedHeight = 150.0
        }
        if (sender.state == UIGestureRecognizerState.Began) {
            if (topBarHeight.constant >= UIScreen.mainScreen().bounds.size.height) {
                self.mapSwipeUpStart = UIScreen.mainScreen().bounds.size.height - location.y
            } else {
                self.mapSwipeUpStart = nil
            }
        }
        if (sender.state == UIGestureRecognizerState.Ended) {
            if (mapSwipeUpStart != nil) {
                if ((UIScreen.mainScreen().bounds.size.height - topBarCalculatedHeight)  > 40) {
                    moveMapViewUp()
                } else {
                    moveMapViewDown()
                }
            } else if (topBarCalculatedHeight > releasePoint) {
                moveMapViewDown()
            } else {
                moveMapViewUp()

            }
            return
        }
        topBarHeight.constant = topBarCalculatedHeight
        if (topBarCalculatedHeight < releasePoint) {
            self.mapView?.alpha = 0.5 +  ((topBarCalculatedHeight - startHeight) / (releasePoint - startHeight)) * 0.5
            self.gradientView.alpha = 1.0 - ((topBarCalculatedHeight - startHeight) / (releasePoint - startHeight))
            self.navBarImage.alpha = 0.0 + ((topBarCalculatedHeight - startHeight) / (releasePoint - startHeight)) * 1.0
            self.releaseToViewLabel.hidden = true
        } else {
            if (mapSwipeUpStart == nil) {
                self.releaseToViewLabel.hidden = false
                if (self.destinationPlacemark == nil) {
                    self.destinationPlacemark = MKPlacemark(coordinate: (station?.coord?.coordinate)!, addressDictionary: nil)
                    self.mapView.addAnnotation(destinationPlacemark)
                }
            }
        }

        if (topBarCalculatedHeight > mapHeight.constant) {
            mapHeight.constant = topBarCalculatedHeight + 200
        }
    }

    func moveMapViewDown() {
        let height = UIScreen.mainScreen().bounds.size.height
        self.releaseToViewLabel.hidden = true
        self.mapView.userInteractionEnabled = true
        if (self.mapHeight.constant < height + 200) {
            self.mapHeight.constant = height + 200
        }
        self.topBarHeight.constant = height
        UIView.animateWithDuration(0.5,
            animations: {
                self.view.layoutIfNeeded()
                return
            }, completion: { (finished:Bool) in
            }
        )
    }

    func moveMapViewUp() {
        let height = CGFloat(startHeight)

        self.mapView.userInteractionEnabled = false
        self.topBarHeight.constant = height
        UIView.animateWithDuration(0.5,
            animations: {
                self.mapView?.alpha = 0.5
                self.gradientView?.alpha = 1.0
                self.navBarImage.alpha = 0.0
                self.topView.layoutIfNeeded()
                return
            }, completion: { (finished:Bool) in
                if (self.destinationPlacemark != nil) {
                    self.mapView.removeAnnotation(self.destinationPlacemark)
                    self.destinationPlacemark = nil
                }
                return
            }
        )
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y + startHeight
        if (offset > 0) {
            if (startHeight - offset >= 44 + 20) {
                topBarHeight.constant = startHeight - offset
                borderBottomView.alpha = offset / 80
                mapView?.alpha = min(1 - (offset / 80), 0.5)
                stationIconView.alpha = 1 - (offset / 80)
            }
        }
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        gestureRecognizer = self.navigationController?.interactivePopGestureRecognizer.delegate
        self.navigationController?.interactivePopGestureRecognizer.delegate = nil
        self.edgesForExtendedLayout = UIRectEdge.None;

        nameLabel.text = self.station?.name
        self.api = APIController(delegate: self)
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.departures = nil;
        self.api?.getDepartures(self.station?.st_id)
        self.refreshControl = UIRefreshControl()
        self.refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.refreshControl.backgroundColor = UIColor(red: 242.0/255.0, green: 243.0/255.0, blue: 245.0/255.0, alpha: 1.0)
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.appsTableView?.addSubview(refreshControl)
        
        startHeight = topBarHeight.constant
        self.appsTableView?.contentInset = UIEdgeInsets(top: startHeight, left: 0, bottom: 0, right: 0)

        var favButton = UIBarButtonItem(title: "☆", style: UIBarButtonItemStyle.Plain, target: self, action: "favoriteClicked:")

        if (station!.isFavorite()) {
           favButton.title = "★";
        }
        
        self.stationIconView.layer.cornerRadius = self.stationIconView.frame.width / 2
        
        self.navigationItem.rightBarButtonItem = favButton
        self.gradientView.image = UIImage(named: "gradient.png")
        self.mapView?.alpha = 0.0
        self.mapView?.userInteractionEnabled = false;

        var region = MKCoordinateRegionMakeWithDistance((station?.coord?.coordinate)! ,300,300);
        self.mapView.setRegion(region, animated: false)
        self.mapView.showsUserLocation = true
        self.mapView.delegate = self

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBecomeInactive:", name: "UIApplicationDidEnterBackgroundNotification", object: nil)
    }

    override func viewWillDisappear(animated: Bool) {
        self.navigationController?.navigationBar.setBackgroundImage(nil, forBarMetrics: UIBarMetrics.Default)
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        self.navigationController?.interactivePopGestureRecognizer.delegate = gestureRecognizer

    }

    func mapViewDidFinishRenderingMap(mapView: MKMapView!, fullyRendered: Bool) {
        if(self.mapView.alpha <= 0.6) {
            UIView.animateWithDuration(0.8,
                delay: 0.0,
                options: UIViewAnimationOptions.CurveLinear,
                animations: {
                    self.mapView?.alpha = 0.5
                    return
                }, completion: { (finished:Bool) in
                }
            )
        }
    }

    func applicationDidBecomeInactive(notification: NSNotification) {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBecomeActive:", name: "UIApplicationDidBecomeActiveNotification", object: nil)

    }
    
    func applicationDidBecomeActive(notification: NSNotification) {
        NSNotificationCenter.defaultCenter().removeObserver(self)
          NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBecomeInactive:", name: "UIApplicationDidEnterBackgroundNotification", object: nil)
        self.departures = nil
        self.api?.getDepartures(self.station?.st_id)
    }

    deinit {
        println("deinit")
         NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    override func viewDidDisappear(animated: Bool) {
        station = nil
        api = nil
        departures = nil
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    @IBAction func favoriteClicked(sender: UIBarButtonItem) {
        if (self.station!.isFavorite()) {
            TFCStations.unsetFavoriteStation(self.station!)
            sender.title = "☆";
        } else {
            TFCStations.setFavoriteStation(self.station!)
            sender.title = "★";
        }
        self.appsTableView?.reloadData()
    }


    func refresh(sender:AnyObject)
    {
        // Code to refresh table view
        self.departures = nil
        self.api?.getDepartures(self.station?.st_id)
    }
    
    internal func setStation(station: TFCStation) {
        self.station = station
        self.departures = nil
    }

    func didReceiveAPIResults(results: JSONValue, error: NSError?, context: Any?) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        self.refreshControl.endRefreshing()
        dispatch_async(dispatch_get_main_queue(), {
            if (error != nil) {
                self.networkErrorMsg = NSLocalizedString("Network error. Please try again", comment:"")
            } else {
                self.networkErrorMsg = nil
            }
            self.departures = TFCDeparture.withJSON(results)
            if (self.station?.name == "") {
                self.station?.name = TFCDeparture.getStationNameFromJson(results)!;
                self.titleLabel.title = self.station?.name
            }
            self.appsTableView!.reloadData()
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        })
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (self.departures == nil || self.departures!.count == 0) {
            return 1
        }
        return self.departures!.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell:MGSwipeTableCell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier) as MGSwipeTableCell

        cell.delegate = self
        cell.tag = indexPath.row


        let lineNumberLabel = cell.viewWithTag(100) as UILabel
        let destinationLabel = cell.viewWithTag(200) as UILabel
        let departureLabel = cell.viewWithTag(300) as UILabel
        let minutesLabel = cell.viewWithTag(400) as UILabel
        if (station != nil) {
            let station2 = station!
            
            if (self.departures == nil || self.departures!.count == 0) {
                departureLabel.text = nil
                lineNumberLabel.text = nil
                minutesLabel.text = nil
                lineNumberLabel.backgroundColor = UIColor.clearColor()
                if (self.departures == nil) {
                    destinationLabel.text = NSLocalizedString("Loading", comment: "Loading ..")
                } else {
                    destinationLabel.text = NSLocalizedString("No departures found.", comment: "")
                    if (self.networkErrorMsg != nil) {
                        departureLabel.text = self.networkErrorMsg
                    }
                }
                return cell
            }
            
            let departure: TFCDeparture = self.departures![indexPath.row]
            
            lineNumberLabel.text = departure.getLine()
            var unabridged = false
            if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
                unabridged = true
            }
            destinationLabel.text = departure.getDestinationWithSign(station, unabridged: unabridged)
            
            
            minutesLabel.text = departure.getMinutes()
            if (station2.isFiltered(departure)) {
                destinationLabel.textColor = UIColor.grayColor()
                minutesLabel.textColor = UIColor.grayColor()
            } else {
                destinationLabel.textColor = UIColor.blackColor()
                minutesLabel.textColor = UIColor.blackColor()
            }
            
            departureLabel.attributedText = departure.getDepartureTime()
            
            lineNumberLabel.layer.cornerRadius = 4.0
            lineNumberLabel.layer.masksToBounds = true
            
            if (departure.colorBg != nil) {
                lineNumberLabel.backgroundColor = UIColor(netHexString:departure.colorBg!);
                lineNumberLabel.textColor = UIColor(netHexString:departure.colorFg!);
            } else {
                lineNumberLabel.textColor = UIColor.blackColor()
                lineNumberLabel.backgroundColor = UIColor.whiteColor()
            }
        }
        return cell
    }

    func swipeTableCell(cell: MGSwipeTableCell!, canSwipe direction: MGSwipeDirection) -> Bool {
        if (direction == MGSwipeDirection.RightToLeft) {
            return true
        }
        return false
    }

    func swipeTableCell(cell: MGSwipeTableCell!, swipeButtonsForDirection direction: MGSwipeDirection, swipeSettings: MGSwipeSettings!, expansionSettings: MGSwipeExpansionSettings!) -> [AnyObject]! {
        var buttons = []
        if (station != nil) {
            let station2 = station!
            if (self.departures != nil) {
                if (direction == MGSwipeDirection.RightToLeft) {
                    let departure: TFCDeparture = self.departures![cell.tag]
                    if (station2.isFiltered(departure)) {
                        buttons = [MGSwipeButton( title:"Unfilter", backgroundColor: UIColor.redColor())]
                    } else {
                        buttons = [MGSwipeButton( title:"Filter", backgroundColor: UIColor.greenColor())]
                    }
                }
                expansionSettings.buttonIndex = 0
                expansionSettings.fillOnTrigger = true
                expansionSettings.threshold = 2.5
            }
        }
        return buttons
    }

    func swipeTableCell(cell: MGSwipeTableCell!, tappedButtonAtIndex index: Int, direction: MGSwipeDirection, fromExpansion: Bool) -> Bool {
        let departure: TFCDeparture = self.departures![cell.tag]
        let station2 = station!
        if (station2.isFiltered(departure)) {
            station2.unsetFilter(departure);
            var button = cell.rightButtons[0] as MGSwipeButton
            button.backgroundColor = UIColor.greenColor();
        } else {
            station2.setFilter(departure);
            var button = cell.rightButtons[0] as MGSwipeButton
            button.backgroundColor = UIColor.redColor();
        }
        self.appsTableView?.reloadData()

        return true
    }

    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        coordinator.animateAlongsideTransition(
            {
                (context) -> Void in
            },
            completion: {
                (context) -> Void in
                self.appsTableView?.reloadData()
                return
        })
    }
}
