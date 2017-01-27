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

        StationFavoriteButton.addTarget(self, action: #selector(NearbyStationsTableViewCell.favoriteButtonTouched(_:)), for: UIControlEvents.touchUpInside)
    }

    func getStation() -> TFCStation? {
        if (station == nil && stationId != nil) {
            station = TFCStation.initWithCacheId(stationId!)
        }
        return station
    }

    func drawCell(_ drawDepartures:Bool = true) {
        self.selectionStyle = UITableViewCellSelectionStyle.none
        if (station == nil && stationId != nil) {
            getStation()
        }
        if (drawDepartures) {
            station?.removeObsoleteDepartures()
        }
        drawIcon(station)

        StationsLineNumberLabel.isHidden = false
        StationNameLabel.text = station?.getNameWithFilters(false)

        if (drawDepartures) {
            let departures = station?.getFilteredDepartures(6)
            var firstDeparture = departures?.first

            var minutesAsInt = firstDeparture?.getMinutesAsInt()
            if (minutesAsInt != nil && minutesAsInt! < 0) {
                station?.removeObsoleteDepartures(true)
                firstDeparture = departures?.first
                minutesAsInt = firstDeparture?.getMinutesAsInt()
            }
            if (firstDeparture != nil && (minutesAsInt != nil && minutesAsInt! >= 0)) {
                StationsLineNumberLabel.setStyle("dark", departure: firstDeparture!)
                StationMinuteLabel.text = firstDeparture!.getMinutes()
                StationsDestinationLabel.text = firstDeparture!.getDestination(station, unabridged: false)
            } else {
                StationsLineNumberLabel.isHidden = true
                StationMinuteLabel.text = nil
                StationsDestinationLabel.text = nil
            }
        } else {
            StationsLineNumberLabel.isHidden = true
            StationMinuteLabel.text = nil
            StationsDestinationLabel.text = nil
        }
        self.isUserInteractionEnabled = true
        self.stationId = self.station?.st_id
    }

    func drawIcon(_ station: TFCStation?) {
        StationFavoriteButton.setImage(station?.getIcon(), for: UIControlState.normal)

        StationIconView.transform = CGAffineTransform(scaleX: 1, y: 1);
        StationIconView.alpha = 1.0

    }

    func favoriteButtonTouched(_ sender: UIButton) {
        if let stationId = stationId {
            let station = TFCStation.initWithCacheId(stationId)

            func completion() -> Void {
                self.drawIcon(station)
                return
            }
            station?.toggleIcon(self.StationFavoriteButton!, icon: StationIconView, completion: completion)
        }
    }

    override func prepareForReuse() {
        self.station = nil
        self.stationId = nil
    }
}
