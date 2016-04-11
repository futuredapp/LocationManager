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
    let minimumTimeInterval: NSTimeInterval?
    let maximumTimeInterval: NSTimeInterval?
    var previousLocation: CLLocation?
    var newLocationForUpdate: CLLocation?
    var minimumTimer: NSTimer?
    var maximumTimer: NSTimer?
    
    init(locationObserver: LocationObserver, locationManager: LocationManager, desiredAccuracy: CLLocationAccuracy?, distanceFilter: CLLocationDistance?, minimumTimeInterval: NSTimeInterval?, maximumTimeInterval: NSTimeInterval?) {
        self.observer = locationObserver
        self.locationManager = locationManager
        self.desiredAccuracy = desiredAccuracy
        self.distanceFilter = distanceFilter
        self.minimumTimeInterval = minimumTimeInterval
        self.maximumTimeInterval = maximumTimeInterval
        
        super.init()
        
        self.initializeTimers()
    }
    
    func invalidate() {
        self.deinitializeTimers()
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
            self.minimumTimer = NSTimer.scheduledTimerWithTimeInterval(interval, target: self, selector: #selector(minimumTimerTick), userInfo: nil, repeats: true)
        }
        if let interval = self.maximumTimeInterval {
            self.maximumTimer = NSTimer.scheduledTimerWithTimeInterval(interval, target: self, selector: #selector(maximumTimerTick), userInfo: nil, repeats: true)
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
    
    func updateLocationFromTimer(location: CLLocation) {
        self.observer.didUpdateLocation(self.locationManager, location: location)
        self.previousLocation = location
        self.newLocationForUpdate = nil
    }
}

func ==(llo: LocationObserverItem, rlo: LocationObserverItem) -> Bool {
    return llo === rlo
}