//
//  LocationCompletionQueue.swift
//  Pods
//
//  Created by Aleš Kocur on 20/05/15.
//  Copyright © 2015 The Funtasty. All rights reserved.
//
//


import CoreLocation

typealias LocationCompletion = CLLocation? -> Void

class LocationRequest: NSObject {
    let completion: LocationCompletion
    let locationManager: LocationManager
    var desiredAccuracy: CLLocationAccuracy?
    var timeout: NSTimeInterval?
    var timer: NSTimer?
    
    init(timeout: NSTimeInterval?, desiredAccuracy: CLLocationAccuracy?, completion: LocationCompletion, locationManager: LocationManager) {
        self.completion = completion
        self.timeout = timeout
        self.desiredAccuracy = desiredAccuracy
        self.locationManager = locationManager
        
        super.init()
        
        if let timeout = timeout {
            self.timer = NSTimer.scheduledTimerWithTimeInterval(timeout, target: self, selector: #selector(didTimeout), userInfo: nil, repeats: false)
        }
    }
    
    func validateLocation(location: CLLocation) -> Bool {
        if location.timestamp.timeIntervalSinceNow < -(self.timeout ?? 30) {
            return false
        }
        if let desiredAccuracy = self.desiredAccuracy {
            return location.horizontalAccuracy <= desiredAccuracy && location.verticalAccuracy <= desiredAccuracy
        }
        return true
    }
    
    func completeWithLocation(location: CLLocation?, force: Bool = false) -> Bool {
        if !force {
            guard let _location = location where self.validateLocation(_location) else {
                return false
            }
        }
        self.completion(location)
        self.timer?.invalidate()
        self.timer = nil
        return true
    }
    
    func didTimeout() {
        self.completeWithLocation(self.locationManager.lastKnownLocation, force: true)
        self.locationManager.locationRequestDidTimeout(self)
    }
    
}

func ==(lhs: LocationRequest, rhs: LocationRequest) -> Bool {
    return lhs === rhs
}
