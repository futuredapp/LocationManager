import CoreLocation

typealias LocationCompletion = (CLLocation?) -> Void

class LocationRequest: NSObject {

    @objc let completion: LocationCompletion
    @objc let locationManager: LocationManager
    var desiredAccuracy: CLLocationAccuracy?
    var timeout: TimeInterval?
    @objc var timer: Timer?

    init(
        timeout: TimeInterval?,
        desiredAccuracy: CLLocationAccuracy?,
        completion: @escaping LocationCompletion,
        locationManager: LocationManager
    ) {

        self.completion = completion
        self.timeout = timeout
        self.desiredAccuracy = desiredAccuracy
        self.locationManager = locationManager

        super.init()

        if let timeout = timeout {
            self.timer = Timer.scheduledTimer(
                timeInterval: timeout,
                target: self,
                selector: #selector(didTimeout),
                userInfo: nil,
                repeats: false
            )
        }
    }

    @objc func validate(location: CLLocation) -> Bool {

        if location.timestamp.timeIntervalSinceNow < -(self.timeout ?? 30) {
            return false
        }

        if let desiredAccuracy = self.desiredAccuracy {
            return location.horizontalAccuracy <= desiredAccuracy && location.verticalAccuracy <= desiredAccuracy
        }

        return true
    }

    @objc func completeWith(location: CLLocation?, force: Bool = false) -> Bool {

        if !force {
            guard let location = location, validate(location: location) else {
                return false
            }
        }

        completion(location)
        timer?.invalidate()
        timer = nil

        return true
    }

    @objc func didTimeout() {

        _ = completeWith(location: locationManager.lastKnownLocation, force: true)
        locationManager.locationRequestDidTimeout(self)
    }
}

func == (lhs: LocationRequest, rhs: LocationRequest) -> Bool {
    return lhs === rhs
}
