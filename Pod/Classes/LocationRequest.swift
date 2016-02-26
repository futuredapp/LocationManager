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

class LocationRequest: Equatable {
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
        
        if let timeout = timeout {
            self.timer = NSTimer.scheduledTimerWithTimeInterval(timeout, target: self, selector: Selector("didTimeout"), userInfo: nil, repeats: false)
        }
    }
    
    func validateLocation(location: CLLocation) -> Bool {
        if let desiredAccuracy = self.desiredAccuracy {
            return location.horizontalAccuracy <= desiredAccuracy && location.verticalAccuracy <= desiredAccuracy
        }
        return true
    }
    
    func completeWithLocation(location: CLLocation?, force: Bool = false) {
        guard let _location = location where force || self.validateLocation(_location) else {
            return
        }
        self.completion(location)
        self.timer?.invalidate()
        self.timer = nil
    }
    
    
    func didTimeout() {
        self.completeWithLocation(self.locationManager.lastKnownLocation, force: true)
        self.locationManager.locationRequestDidTimeout(self)
    }
    
}

func ==(lhs: LocationRequest, rhs: LocationRequest) -> Bool {
    return lhs === rhs
}
