//
//  LocationObserver.swift
//  Pods
//
//  Created by Jakub Knejzlik on 25/02/16.
//
//

import CoreLocation

public protocol LocationObserver: AnyObject {
    func didUpdateLocation(_ manager: LocationManager, location: CLLocation)
}

class LocationObserverItem: NSObject {

    let observer: LocationObserver
    let locationManager: LocationManager
    let desiredAccuracy: CLLocationAccuracy?
    let distanceFilter: CLLocationDistance?
    let minimumTimeInterval: TimeInterval?
    let maximumTimeInterval: TimeInterval?
    var previousLocation: CLLocation?
    var newLocationForUpdate: CLLocation?
    var minimumTimer: Timer?
    var maximumTimer: Timer?
    
    init(locationObserver: LocationObserver, locationManager: LocationManager, desiredAccuracy: CLLocationAccuracy?, distanceFilter: CLLocationDistance?, minimumTimeInterval: TimeInterval?, maximumTimeInterval: TimeInterval?) {

        observer = locationObserver
        self.locationManager = locationManager
        self.desiredAccuracy = desiredAccuracy
        self.distanceFilter = distanceFilter
        self.minimumTimeInterval = minimumTimeInterval
        self.maximumTimeInterval = maximumTimeInterval
        
        super.init()
        
        initializeTimers()
    }
    
    func invalidate() {
        deinitializeTimers()
    }
    
    func validate(location: CLLocation) -> Bool {

        if let desiredAccuracy = desiredAccuracy , desiredAccuracy < location.horizontalAccuracy || desiredAccuracy < location.verticalAccuracy {
            return false
        }

        if let distanceFilter = distanceFilter , let previousLocation = previousLocation , previousLocation.distance(from: location) <= distanceFilter {
            return false
        }

        return true
    }
    
    func update(location: CLLocation?) {

        guard let location = location , self.validate(location: location) else {
            return
        }

        if self.validate(location: location) {

            if self.minimumTimer != nil && self.previousLocation != nil {
                self.newLocationForUpdate = location
            } else {
                self.observer.didUpdateLocation(self.locationManager, location: location)
                self.previousLocation = location
            }
        }
    }
    
    // Mark: - Timer methods
    
    func deinitializeTimers() {

        self.minimumTimer?.invalidate()
        self.minimumTimer = nil
        self.maximumTimer?.invalidate()
        self.maximumTimer = nil
    }
    
    func initializeTimers() {

        if let interval = self.minimumTimeInterval {
            self.minimumTimer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(minimumTimerTick), userInfo: nil, repeats: true)
        }

        if let interval = self.maximumTimeInterval {
            self.maximumTimer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(maximumTimerTick), userInfo: nil, repeats: true)
        }
    }
    
    func minimumTimerTick() {

        if let location = self.newLocationForUpdate {
            self.updateLocationFromTimer(location)
        }
    }
    
    func maximumTimerTick() {

        if let location = self.newLocationForUpdate ?? self.previousLocation {
            self.updateLocationFromTimer(location)
        }
    }
    
    func updateLocationFromTimer(_ location: CLLocation) {

        self.observer.didUpdateLocation(self.locationManager, location: location)
        self.previousLocation = location
        self.newLocationForUpdate = nil
    }
}

func ==(llo: LocationObserverItem, rlo: LocationObserverItem) -> Bool {
    return llo === rlo
}
