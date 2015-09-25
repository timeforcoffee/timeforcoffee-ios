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

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        StationIconView.layer.cornerRadius = StationIconView.layer.bounds.width / 2
        StationIconView.clipsToBounds = true

        StationFavoriteButton.addTarget(self, action: "favoriteButtonTouched:", forControlEvents: UIControlEvents.TouchUpInside)
    }


    func drawCell() {
        self.selectionStyle = UITableViewCellSelectionStyle.None;
        drawIcon()
        let departures = station?.getFilteredDepartures(1)
        let firstDeparture = departures?.first
     /*   let iconLabel = cell.viewWithTag(500) as! UIImageView
        iconLabel.layer.cornerRadius = iconLabel.layer.bounds.width / 2
        iconLabel.clipsToBounds = true
        iconLabel.image = station?.getIcon()
        iconLabel.hidden = false*/
        StationsLineNumberLabel.hidden = false
        StationNameLabel.text = station?.getNameWithFilters(false)

        if (firstDeparture != nil && firstDeparture?.getMinutesAsInt() >= 0) {
            StationsLineNumberLabel.setStyle("dark", departure: firstDeparture!)
            StationMinuteLabel.text = firstDeparture!.getMinutes()
            StationsDestinationLabel.text = firstDeparture!.getDestination(station, unabridged: false)
        } else {
            StationsLineNumberLabel.hidden = true
            StationMinuteLabel.text = nil
            StationsDestinationLabel.text = nil
        }
        self.userInteractionEnabled = true
    }

    func drawIcon() {
        StationFavoriteButton.setImage(station?.getIcon(), forState: UIControlState.Normal)
        StationIconView.transform = CGAffineTransformMakeScale(1, 1);
        StationIconView.alpha = 1.0

    }

    func favoriteButtonTouched(sender: UIButton) {

        func completion() -> Void {
            self.drawIcon()
            return
        }

        self.station?.toggleIcon(self.StationFavoriteButton!, icon: StationIconView, completion: completion)

    }


}