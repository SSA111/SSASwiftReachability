![SSASideMenu](https://github.com/SSA111/SSASwiftReachability/blob/master/SSASwiftReachabilityCover.png)

[![](http://img.shields.io/badge/iOS-8.0%2B-blue.svg)]() [![](http://img.shields.io/badge/Swift-2.0-blue.svg)]() 

Inspired by AFNetworkReachabilityManager

###Usage

```swift
    override func viewDidLoad() {
        super.viewDidLoad()
        
         // MARK: Start Monitoring For Network Reachability Changes.
        SSASwiftReachability.sharedManager?.startMonitoring()
        
        // MARK: Listen For Network Reachability Changes
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reachabilityStatusChanged:", name: reachabilityDidChangeNotification, object: nil)
    }
    
    func reachabilityStatusChanged(notification: NSNotification) {
        if let info = notification.userInfo {

            if let s = info[reachabilityNotificationStatusItem] {
                print(s.description)
            }
        }
    }
    
```
###Installation 
As for now please clone the repository and drag the source folder into your project to use SSASwiftReachability. (Cocoapods & Carthage
support coming soon) 

###Author

Sebastian Andersen

###License

SSASwiftReachability is available under the MIT license. See the LICENSE file for more info.
