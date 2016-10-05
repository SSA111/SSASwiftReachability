![SSASideMenu](https://github.com/SSA111/SSASwiftReachability/blob/master/SSASwiftReachabilityCover.png)

[![](http://img.shields.io/badge/iOS-8.0%2B-blue.svg)]() [![](http://img.shields.io/badge/Swift-3.0-blue.svg)]()

###Usage

```swift
    override func viewDidLoad() {
    super.viewDidLoad()

    SSASwiftReachability.sharedManager?.startMonitoring()

    // MARK: Listen For Network Reachability Changes
    NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityStatusChanged(notification:)), name: NSNotification.Name(rawValue: SSAReachabilityDidChangeNotification), object: nil)
    }

    func reachabilityStatusChanged(notification: NSNotification) {
    if let info = notification.userInfo {
        if let s = info[SSAReachabilityNotificationStatusItem] {
            reachabilityStatusLabel.text = (s as AnyObject).description
        }
    }
    }
```
###Installation
As for now please clone the repository and drag the source folder into your project to use SSASwiftReachability. (Cocoapods & Carthage
support coming soon)

###Author

Sebastian Andersen

Inspired by AFNetworkReachabilityManager

###License

SSASwiftReachability is available under the MIT license. See the LICENSE file for more info.
