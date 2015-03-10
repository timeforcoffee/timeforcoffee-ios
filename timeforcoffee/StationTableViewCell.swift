//
//  StationTableViewCell.swift
//  timeforcoffee
//
//  Created by Jan Hug on 04.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import UIKit
import timeforcoffeeKit

class StationTableViewCell: UITableViewCell {
    @IBOutlet weak var StationIconView: UIView!
    @IBOutlet weak var StationNameLabel: UILabel!
    @IBOutlet weak var StationDescriptionLabel: UILabel!
    @IBOutlet weak var StationFavoriteButton: UIButton!

    lazy var station: TFCStation = TFCStation()

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        StationIconView.layer.cornerRadius = StationIconView.layer.bounds.width / 2
        StationIconView.clipsToBounds = true
        
        StationFavoriteButton.addTarget(self, action: "favoriteButtonTouched:", forControlEvents: UIControlEvents.TouchUpInside)
    }

    deinit {
        println("cell deinit")
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func favoriteButtonTouched(sender: UIButton) {
        println(station.isFavorite())
        station.toggleFavorite()
        drawFavoriteIcon()
    }

    func drawCell() {
        self.selectionStyle = UITableViewCellSelectionStyle.None;
        drawFavoriteIcon()
        let parent = self.superview?.superview as StationTableView
        let locManager = parent.locManager
        StationNameLabel?.text = station.getName(false)

        if (locManager.currentLocation == nil) {
            StationDescriptionLabel.text = ""
            return
        }

        if (station.coord != nil) {
            var distance = station.getDistanceInMeter(locManager.currentLocation)
            if (distance > 5000) {
                let km = Int(round(Double(distance!) / 1000))
                StationDescriptionLabel.text = "\(km) Kilometer"
            } else {
                StationDescriptionLabel.text = "\(distance!) Meter"
                // calculate exact distance
                station.getWalkingDistance(locManager.currentLocation, completion: {
                    text in
                    if (text != nil) {
                        self.StationDescriptionLabel.text = text
                    }
                })
            }
        } else {
            StationDescriptionLabel.text = ""
        }
    }

    func drawFavoriteIcon() {
        if (station.isFavorite() == true) {
            StationIconView.backgroundColor = UIColor(red: 249, green: 205, blue: 70)
        } else {
            StationIconView.backgroundColor = UIColor(red: 197, green: 197, blue: 197)
        }
    }

}
