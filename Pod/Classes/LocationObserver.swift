//
//  LocationObserver.swift
//  Pods
//
//  Created by Jakub Knejzlik on 25/02/16.
//
//

import CoreLocation

public protocol LocationObserver: AnyObject {
    
    func didUpdateLocation(manager: LocationManager, location: CLLocation)
    
}

class LocationObserverItem: NSObject {
    let observer: LocationObserver
    let locationManager: LocationManager
    let desiredAccuracy: CLLocationAccuracy?
    let distanceFilter: CLLocationDistance?
    var previousLocation: CLLocation?
    
    init(locationObserver: LocationObserver, locationManager: LocationManager, desiredAccuracy: CLLocationAccuracy?, distanceFilter: CLLocationDistance?) {
        self.observer = locationObserver
        self.locationManager = locationManager
        self.desiredAccuracy = desiredAccuracy
        self.distanceFilter = distanceFilter
    }
    
    func validateLocation(location: CLLocation) -> Bool {
        if let desiredAccuracy = self.desiredAccuracy where desiredAccuracy < location.horizontalAccuracy || desiredAccuracy < location.verticalAccuracy {
            return false
        }
        if let distanceFilter = self.distanceFilter, previousLocation = self.previousLocation where previousLocation.distanceFromLocation(location) <= distanceFilter {
            return false
        }
        return true
    }
    
    func updateLocation(location: CLLocation?) {
        guard let location = location where self.validateLocation(location) else {
            return
        }
        if self.validateLocation(location) {
            self.observer.didUpdateLocation(self.locationManager, location: location)
            self.previousLocation = location
        }
    }
}

func ==(llo: LocationObserverItem, rlo: LocationObserverItem) -> Bool {
    return llo === rlo
}