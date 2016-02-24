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

```
import LocationManager

LocationManager.sharedManager.getCurrentLocation().then { location in
    print("your current location: \(location)")
}.error { error in
    print("error getting location: \(error)")
}
```

## License

LocationManager is available under the MIT license. See the LICENSE file for more info.
