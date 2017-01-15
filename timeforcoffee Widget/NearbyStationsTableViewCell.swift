//
//  NearbyStationsTableViewCell.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 12.04.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import timeforcoffeeKit

final class NearbyStationsTableViewCell: UITableViewCell {

    @IBOutlet weak var StationsLineNumberLabel: DepartureLineLabelForToday!
    @IBOutlet weak var StationMinuteLabel: UILabel!
    @IBOutlet weak var StationNameLabel: UILabel!
    @IBOutlet weak var StationsDestinationLabel: UILabel!

    @IBOutlet weak var StationIconView: UIView!
    @IBOutlet weak var StationFavoriteButton: UIButton!

    weak var station: TFCStation?
    var stationId: String?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        StationIconView.layer.cornerRadius = 16
        StationIconView.clipsToBounds = true

        StationFavoriteButton.addTarget(self, action: #selector(NearbyStationsTableViewCell.favoriteButtonTouched(_:)), forControlEvents: UIControlEvents.TouchUpInside)
    }

    func getStation() -> TFCStation? {
        if (station == nil && stationId != nil) {
            station = TFCStation.initWithCacheId(stationId!)
        }
        return station
    }

    func drawCell() {
        self.selectionStyle = UITableViewCellSelectionStyle.None
        if (station == nil && stationId != nil) {
            getStation()
        }
        station?.removeObsoleteDepartures()
        drawIcon(station)
        let departures = station?.getFilteredDepartures(6)
        var firstDeparture = departures?.first
     /*   let iconLabel = cell.viewWithTag(500) as! UIImageView
        iconLabel.layer.cornerRadius = iconLabel.layer.bounds.width / 2
        iconLabel.clipsToBounds = true
        iconLabel.image = station?.getIcon()
        iconLabel.hidden = false*/
        StationsLineNumberLabel.hidden = false
        StationNameLabel.text = station?.getNameWithFilters(false)

        var minutesAsInt = firstDeparture?.getMinutesAsInt()
        if (minutesAsInt < 0) {
            station?.removeObsoleteDepartures(true)
            firstDeparture = departures?.first
            minutesAsInt = firstDeparture?.getMinutesAsInt()
        }
        if (firstDeparture != nil && minutesAsInt >= 0) {
            StationsLineNumberLabel.setStyle("dark", departure: firstDeparture!)
            StationMinuteLabel.text = firstDeparture!.getMinutes()
            StationsDestinationLabel.text = firstDeparture!.getDestination(station, unabridged: false)
        } else {
            StationsLineNumberLabel.hidden = true
            StationMinuteLabel.text = nil
            StationsDestinationLabel.text = nil
        }
        self.userInteractionEnabled = true
        self.stationId = self.station?.st_id
    }

    func drawIcon(station: TFCStation?) {
        StationFavoriteButton.setImage(station?.getIcon(), forState: UIControlState.Normal)

        StationIconView.transform = CGAffineTransformMakeScale(1, 1);
        StationIconView.alpha = 1.0

    }

    func favoriteButtonTouched(sender: UIButton) {
        if let stationId = stationId {
            let station = TFCStation.initWithCacheId(stationId)

            func completion() -> Void {
                self.drawIcon(station)
                return
            }
            station.toggleIcon(self.StationFavoriteButton!, icon: StationIconView, completion: completion)
        }
    }

    override func prepareForReuse() {
        self.station = nil
        self.stationId = nil
    }
}
