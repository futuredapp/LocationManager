//
//  LocationManager.swift
//  Pods
//
//  Created by Aleš Kocur on 20/05/15.
//  Copyright © 2015 The Funtasty. All rights reserved.
//
//

import CoreLocation
import PromiseKit


enum LocationManagerError: ErrorType {
    case LocationServiceDisabled
    case CannotFetchLocation
}



public class LocationManager: NSObject, CLLocationManagerDelegate {
    
    public static let sharedManager = LocationManager()
    
    private let locationManager = CLLocationManager()
    
    lazy private var locationCompletionQueue: LocationCompletionQueue = {
        let queue = LocationCompletionQueue(locationManager: self)
        return queue
    }()
    
    private var locationObservers: [LocationObserver] = []
    
    static let locationDidUpdatePermissionsNotification = "locationDidUpdatePermissions"
    
    var currentLocation: CLLocation?
    
    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.distanceFilter = 0
        self.locationManager.desiredAccuracy = 0
        
        self.askForLocationServicesIfNeeded()
    }
    
    
    public func isLocationStatusDetermined() -> Bool {
        return CLLocationManager.authorizationStatus() != CLAuthorizationStatus.NotDetermined
    }
    
    public func isLocationAvailable() -> Bool {
        return CLLocationManager.locationServicesEnabled() && (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.AuthorizedAlways || CLLocationManager.authorizationStatus() == CLAuthorizationStatus.AuthorizedWhenInUse)
    }
    
    func askForLocationServicesIfNeeded() {
        if self.isLocationStatusDetermined() {
            return
        }
        
        if NSBundle.mainBundle().objectForInfoDictionaryKey("NSLocationAlwaysUsageDescription") != nil {
            if self.locationManager.respondsToSelector("requestAlwaysAuthorization"){
                self.locationManager.requestAlwaysAuthorization()
            }
        } else if NSBundle.mainBundle().objectForInfoDictionaryKey("NSLocationWhenInUseUsageDescription") != nil {
            if self.locationManager.respondsToSelector("requestWhenInUseAuthorization") {
                self.locationManager.requestWhenInUseAuthorization();
            }
        }else{
            print("[LocationManager ERROR] The keys NSLocationAlwaysUsageDescription or NSLocationWhenInUseUsageDescription are not defined in your tiapp.xml.  Starting with iOS8 this are required.")
        }
    }
    
    
    func startUpdatingLocationIfNeeded() {
        if self.locationCompletionQueue.queueItems.count > 0 || self.locationObservers.count > 0 {
            self.locationManager.startUpdatingLocation()
        }
    }
    func stopUpdatingLocationIfPossible() {
        if self.locationCompletionQueue.queueItems.count == 0 && self.locationObservers.count == 0 {
            self.locationManager.stopUpdatingLocation()
        }
    }
    
    // MARK: - current location
    
    public func getCurrentLocation(timeout timeout: NSTimeInterval? = 8.0, force: Bool = false) -> Promise<CLLocation> {
        return Promise { success, reject in
            
            if !isLocationAvailable() && self.isLocationStatusDetermined() {
                reject(LocationManagerError.LocationServiceDisabled)
                return
            }
            
            if let currentLocation = currentLocation where !force {
                success(currentLocation)
            } else {
                self.updateLocation(timeout: timeout) { location in
                    if let location = location {
                        success(location)
                    } else {
                        reject(LocationManagerError.CannotFetchLocation)
                    }
                }
            }
        }
    }

    // MARK: - location observers
    
    public func addLocationObserver(observer: LocationObserver) {
        self.locationObservers.append(observer)
        
        self.startUpdatingLocationIfNeeded()
    }
    
    public func removeLocationObserver(observer: LocationObserver) {
        if let index = self.locationObservers.indexOf({ (_observer) -> Bool in
            return observer === _observer
        }) {
            self.locationObservers.removeAtIndex(index)
        }
        
        self.stopUpdatingLocationIfPossible()
    }

    
    // MARK: - CLLocationManagerDelegate
    
    internal var lastKnownLocation: CLLocation?
    
    func updateLocation(timeout timeout: NSTimeInterval?, completion: LocationCompletion) {
        
        self.locationCompletionQueue.pushCompletionItem(timeout, completionItem: completion)
        
        self.startUpdatingLocationIfNeeded()
    }
    
    public func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        NSNotificationCenter.defaultCenter().postNotificationName(LocationManager.locationDidUpdatePermissionsNotification, object: nil)
    }
    
    public func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let lastLocation = locations.last {
            self.lastKnownLocation = lastLocation
            
            if self.validateLocation(lastLocation) {
                self.locationCompletionQueue.completeWithLocation(lastLocation)
                
                for observer in self.locationObservers {
                    observer.didUpdateLocation(self, location: lastLocation)
                }
            }
        }
        self.stopUpdatingLocationIfPossible()
    }
    
    func validateLocation(location: CLLocation) -> Bool {
        print(location,location.horizontalAccuracy,location.verticalAccuracy)
        return location.horizontalAccuracy <= 100 && location.verticalAccuracy <= 100
    }
    
}
