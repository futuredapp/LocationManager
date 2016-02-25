//
//  ViewController.swift
//  LocationManager
//
//  Created by Jakub Knejzlik on 02/24/2016.
//  Copyright (c) 2016 Jakub Knejzlik. All rights reserved.
//

import UIKit
import LocationManager
import CoreLocation

class ViewController: UIViewController, LocationObserver {

    @IBOutlet var locationLabel: UILabel!
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        LocationManager.sharedManager.addLocationObserver(self)
    }
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        LocationManager.sharedManager.removeLocationObserver(self)
    }
    
    func updateLocation() {
        LocationManager.sharedManager.getCurrentLocation().then { location in
            self.locationLabel.text = "\(location.coordinate.latitude) \(location.coordinate.longitude)"
        }.error { error in
            self.locationLabel.text = "cannot fetch location"
        }
    }

    func didUpdateLocation(manager: LocationManager, location: CLLocation) {
        self.locationLabel.text = "\(location.coordinate.latitude) \(location.coordinate.longitude)"
    }
}

