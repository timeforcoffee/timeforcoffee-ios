//
//  StationTableViewCell.swift
//  timeforcoffee
//
//  Created by Jan Hug on 04.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import UIKit
import timeforcoffeeKit

final class StationTableViewCell: UITableViewCell {
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
        DLog("cell deinit")
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func favoriteButtonTouched(sender: UIButton) {

        func completion() -> Void {
            self.drawIcon()
            return
        }

        self.station.toggleIcon(self.StationFavoriteButton!, icon: StationIconView, completion: completion)
        if let currentUser = SKTUser.currentUser() {
            currentUser.addProperties(["usedFavorites": true])
        }
    }

    func drawCell() {
        self.selectionStyle = UITableViewCellSelectionStyle.None;
        drawIcon()
        StationNameLabel?.text = station.getName(false)
        StationNameLabel.accessibilityLabel = station.getName(true)
        if ( TFCLocationManager.getCurrentLocation() == nil) {
            StationDescriptionLabel.text = ""
            return
        }

        StationDescriptionLabel.text = station.getDistanceForDisplay( TFCLocationManager.getCurrentLocation(), completion: {
            text in
            if (text != nil) {
                self.StationDescriptionLabel.text = text
            }
        })
    }

    func drawIcon() {
        StationFavoriteButton.setImage(station.getIcon(), forState: UIControlState.Normal)
        StationIconView.transform = CGAffineTransformMakeScale(1, 1);
        StationIconView.alpha = 1.0
        StationFavoriteButton.isAccessibilityElement = false

    }

}
