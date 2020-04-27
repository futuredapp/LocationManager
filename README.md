# LocationManager

[![CI Status](http://img.shields.io/travis/Jakub Knejzlik/LocationManager.svg?style=flat)](https://travis-ci.org/Jakub Knejzlik/LocationManager)
[![Version](https://img.shields.io/cocoapods/v/LocationManager.svg?style=flat)](http://cocoapods.org/pods/LocationManager)
[![License](https://img.shields.io/cocoapods/l/LocationManager.svg?style=flat)](http://cocoapods.org/pods/LocationManager)
[![Platform](https://img.shields.io/cocoapods/p/LocationManager.svg?style=flat)](http://cocoapods.org/pods/LocationManager)

## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

LocationManager is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "LocationManager"
```

## Example 

### Getting current location

```swift
import LocationManager
import PromiseKit

let desiredAccuracy: CLLocationAccuracy? = kCLLocationAccuracyBestForNavigation

LocationManager.sharedManager.getCurrentLocation(desiredAccuracy: desiredAccuracy).done { location in
    print("your current location: \(location)")
}.catch { error in
    print("error getting location: \(error)")
}
```

When using location observing, you can use these parameters:

* `desiredAccuracy: CLLocationAccuracy?` - specifies desired accuracy (see CoreLocation documentations for more info)

### Observing location

```swift
import LocationManager

class MyObserver: LocationObserver {
    func didUpdateLocation(manager: LocationManager, location: CLLocation) {
        print("your location changed \(location)")
    }
}

let desiredAccuracy: CLLocationAccuracy? = kCLLocationAccuracyBestForNavigation
let distanceFilter: CLLocationDistance? = 50 // meters
let observer = MyObserver()

LocationManager.sharedManager.addLocationObserver(observer, desiredAccuracy: desiredAccuracy, distanceFilter: distanceFilter)

```

When using location observing, you can use these parameters:

* `desiredAccuracy: CLLocationAccuracy?` - specifies desired accuracy (see CoreLocation documentations for more info)
* `distanceFilter: CLLocationDistance?` - filter distances (desired distance between new location and previous location)
* `minimumTimeInterval: TimeInterval?` - specifies how often should location update method be called (minimum interval between calls - max frequency)
* `maximumTimeInterval: TimeInterval?` - forces location update calls event even if there's no new location available (maximum interval between calls)


## Distance Filter and Desired Accuracy

`LocationManager` efficiently uses filter and accuracy of all requests and observers and calculates maximum required values to prevent battery draining. 

For example if you have two observers with 50m and 100m distance filter, the overall distance filter would be 50m. When you remove the observer with 50m filter, the overall distance filter is recalculated to maximum required value (which is 100m). The same applies to `desiredAccuracy`.

## License

LocationManager is available under the MIT license. See the LICENSE file for more info.
