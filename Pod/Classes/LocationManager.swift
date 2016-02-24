//
//  LocationManager.swift
//  Pods
//
//  Created by Jakub Knejzlik on 24/02/16.
//
//

import CoreLocation
//import Bond
import PromiseKit


enum LocationManagerError: ErrorType {
    case LocationServiceDisabled
    case CannotFetchLocation
}

typealias LocationCompletion = CLLocation? -> Void

class LocationCompletionQueue: NSObject {
    
    let locationManager: LocationManager
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }
    
    
//    var lastBestLocation: CLLocation? = nil
    var queueItems: [LocationCompletionQueueItem] = []
    
    var isActive: Bool {
        return timer != nil
    }
    
    private var timer: NSTimer?
    
    func pushCompletionItem(timeout: NSTimeInterval? = nil, completionItem: LocationCompletion) {
        queueItems.append(LocationCompletionQueueItem(timeout: timeout, completion: completionItem))
        
        self.startTimerIfNeeded()
    }
    
    // MARK: - Timer
    
    func startTimerIfNeeded() {
        if timer != nil || queueItems.count == 0 {
            return
        }
        
        timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("tick"), userInfo: nil, repeats: true)
    }
    
    func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func tick() {
        
        var toDelete: [LocationCompletionQueueItem] = []
        
        for item in queueItems {
            if item.timeout == nil {
                continue
            } else if item.timeout == 0 {
//                self.locationManager.currentLocation
//                LocationManager.currentLocation.next(self.lastBestLocation)
                item.completion(self.locationManager.lastKnownLocation)
                toDelete.append(item)
            } else {
                item.timeout! -= 1
            }
        }
        
        for objectForDelete in toDelete {
            if let index = queueItems.indexOf(objectForDelete) {
                queueItems.removeAtIndex(index)
            }
        }
        
        if queueItems.count == 0 {
            invalidateTimer()
            locationManager.locationManager.stopUpdatingLocation()
        }
    }
    
    // MARK: - Run
    
    func completeWithLocation(location: CLLocation) {
        invalidateTimer()
        queueItems.forEach { $0.completion(location) }
        queueItems.removeAll()
    }
}

class LocationCompletionQueueItem: Equatable {
    let completion: LocationCompletion
    var timeout: NSTimeInterval?
    
    init(timeout: NSTimeInterval?, completion: LocationCompletion) {
        self.completion = completion
        self.timeout = timeout
    }
}

func ==(lhs: LocationCompletionQueueItem, rhs: LocationCompletionQueueItem) -> Bool {
    return lhs === rhs
}

public class LocationManager: NSObject, CLLocationManagerDelegate {
    
    public static let sharedManager = LocationManager()
    private let locationManager = CLLocationManager()
    lazy private var locationCompletionQueue: LocationCompletionQueue = {
        let queue = LocationCompletionQueue(locationManager: self)
        return queue
    }()
    
    static let locationDidUpdatePermissionsNotification = "locationDidUpdatePermissions"
    
//    private static let _locationManager = CLLocationManager()
//    class func registerForPermissionsUpdate() {
//        _locationManager.delegate = sharedManager
//    }
    var currentLocation: CLLocation?
    
    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.distanceFilter = 0
        self.locationManager.desiredAccuracy = 0
        
        self.askForLocationServicesIfNeeded()
    }
    
//    @objc class func __bridged__currentLocation() -> CLLocation? {
//        return currentLocation.value
//    }
    
    public func isLocationStatusDetermined() -> Bool {
        return CLLocationManager.authorizationStatus() != CLAuthorizationStatus.NotDetermined
    }
    
    public func isLocationAvailable() -> Bool {
        return CLLocationManager.locationServicesEnabled() && (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.AuthorizedAlways || CLLocationManager.authorizationStatus() == CLAuthorizationStatus.AuthorizedWhenInUse)
    }
    
//    @objc class func __getCurrentLocation(timeout timeout: NSTimeInterval, force: Bool, completion: CLLocation? -> Void) {
//        self.getCurrentLocation(timeout: timeout, force: force).then { location in
//            completion(location)
//        }.error { _ in
//            completion(nil)
//        }
//    }
    
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
        if self.locationCompletionQueue.queueItems.count > 0 {
            self.locationManager.startUpdatingLocation()
        }
    }
    func stopUpdatingLocationIfPossible() {
        if self.locationCompletionQueue.queueItems.count == 0 {
            self.locationManager.stopUpdatingLocation()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
//    private var locationCompletion: LocationCompletion?
    private var lastKnownLocation: CLLocation?
    
    func updateLocation(timeout timeout: NSTimeInterval?, completion: LocationCompletion) {
        
//        let isActive = self.locationCompletionQueue.isActive
        
        self.locationCompletionQueue.pushCompletionItem(timeout, completionItem: completion)
        
//        if !isActive {
//            self.locationManager.startUpdatingLocation()
//        }
        self.startUpdatingLocationIfNeeded()
    }
    
    public func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        NSNotificationCenter.defaultCenter().postNotificationName(LocationManager.locationDidUpdatePermissionsNotification, object: nil)
    }
    
    public func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let lastLocation = locations.last {
            self.lastKnownLocation = lastLocation
//            self.locationCompletionQueue.lastBestLocation = lastLocation
            
            if self.validateLocation(lastLocation) {
                self.locationCompletionQueue.completeWithLocation(lastLocation)
            }
        }
        self.stopUpdatingLocationIfPossible()
    }
    
    func validateLocation(location: CLLocation) -> Bool {
        return location.horizontalAccuracy <= 100 && location.verticalAccuracy <= 100
    }
    
}
