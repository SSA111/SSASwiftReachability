//
//  SSASwiftReachability.swift
//  SSASwiftReachability
//
//  Created by Sebastian Andersen on 05/02/15.
//  Copyright (c) 2015 SebastianAndersen. All rights reserved.
//

import SystemConfiguration
import Foundation

let SSAReachabilityDidChangeNotification  = "ReachabilityChangedNotification"
let SSAReachabilityNotificationStatusItem = "ReachabilityNotificationStatusItem"

func callback(target: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer?) {
    
    let reachability = Unmanaged<SSASwiftReachability>.fromOpaque(UnsafeRawPointer(OpaquePointer(info))!).takeUnretainedValue()
    
    DispatchQueue.main.async {
        reachability.reachabilityCallback(flags)
    }
}



open class SSASwiftReachability {
    
    typealias ReachabilityStatusChangedClosure = (ReachabilityStatus) -> ()
    
    // MARK: Public Enums
    
    enum ReachabilityStatus: Int {
        case unknown = -1
        case notReachable = 0
        case reachableViaWWAN = 1
        case reachableViaWiFi = 2
        case reachable = 3
        
        var description : String {
            get {
                switch(self) {
                case .unknown:
                    return "Unknown"
                case .notReachable:
                    return "Not Reachable"
                case .reachableViaWWAN:
                    return "Reachable Via WWAN"
                case .reachableViaWiFi:
                    return "Reachable Via WiFi"
                case .reachable:
                    return "Reachable"
                }
            }
        }
    }
    
    enum ReachabilityAssociation: Int {
        case forAddress = 1
        case forAddressPair = 2
        case forName = 3
    }
    
    enum ReachabilityInformationMode: Int {
        case simple = 1
        case advanced = 2
    }
    
    // MARK: Public Variables
    
    var networkReachabilityStatus: ReachabilityStatus = .unknown
    var reachabilityAssociation: ReachabilityAssociation = .forName
    var reachabilityInformationMode: ReachabilityInformationMode = .simple
    
    var currentReachabilityString: String {
        return networkReachabilityStatus.description
    }
    
    // MARK: Public Optional Variables
    
    var reachabilityStatusChangedClosure: ReachabilityStatusChangedClosure?
    
    // MARK: Public Class Variables
    
    class var zeroAdress: sockaddr_in {
        var address: sockaddr_in = sockaddr_in(sin_len: __uint8_t(0), sin_family: sa_family_t(0), sin_port: in_port_t(0), sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        address.sin_len = UInt8(MemoryLayout.size(ofValue: address))
        address.sin_family = sa_family_t(AF_INET)
        
        return address
    }
    
    // MARK: Private Variables
    
    fileprivate var networkReachability: SCNetworkReachability?
    fileprivate var lastNetworkReachabilityStatus: ReachabilityStatus = .unknown
    
    // MARK: Singleton
    
    static let sharedManager: SSASwiftReachability? = SSASwiftReachability.managerForAddress(SSASwiftReachability.zeroAdress)
    
    // MARK: Initialization
    
    fileprivate init(reachabilityRef: SCNetworkReachability, reachabilityAssociation: ReachabilityAssociation) {
        self.networkReachability = reachabilityRef
        self.reachabilityAssociation = reachabilityAssociation
    }
    
    // MARK: Public Class Functions
    
    class func managerForDomain(_ domain: String) -> SSASwiftReachability? {
        let reachabilityRef: SCNetworkReachability? = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, (domain as NSString).utf8String!)
        return SSASwiftReachability(reachabilityRef: reachabilityRef!, reachabilityAssociation: .forName)
    }
    
    class func managerForAddress(_ address: sockaddr_in) -> SSASwiftReachability? {
        var addressVar = address
        let reachabilityRef = withUnsafePointer(to: &addressVar) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        return SSASwiftReachability(reachabilityRef: reachabilityRef! as SCNetworkReachability, reachabilityAssociation: .forAddress)
    }
    
    // MARK: Public Functions
    
    func isReachable() -> Bool {
        return networkReachabilityStatus == .reachable || networkReachabilityStatus == .reachableViaWWAN || networkReachabilityStatus == .reachableViaWiFi
    }
    
    func isReachableViaWWAN() -> Bool {
        return networkReachabilityStatus == .reachableViaWWAN
    }
    
    func isReachableViaWiFi() -> Bool {
        return networkReachabilityStatus == .reachableViaWiFi
    }
    
    // MARK: Start Monitoring For Reachability Changes
    
    func startMonitoring() {
        stopMonitoring()
        guard let reachability = networkReachability else { return }
        
        let statusClosure: ReachabilityStatusChangedClosure = { [weak self] status in
            self?.networkReachabilityStatus = status
        }
        
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = Unmanaged.passUnretained(self).toOpaque()
        
        
        SCNetworkReachabilitySetCallback(reachability, callback, &context)
        SCNetworkReachabilityScheduleWithRunLoop(reachability, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        
        
        
        
        // Get Initial Reachability Status
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.background).async {
            var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags()
            SCNetworkReachabilityGetFlags(reachability, &flags)
            let status: ReachabilityStatus = self.reachabilityStatus(flags)
            
            DispatchQueue.main.async {
                statusClosure(status)
                NotificationCenter.default.post(name: Notification.Name(rawValue: SSAReachabilityDidChangeNotification), object:self, userInfo: [SSAReachabilityNotificationStatusItem : "\(status)"])
            }
        }
    }
    
    // MARK: Stop Monitoring For Reachability Changes
    
    func stopMonitoring() {
        guard let reachability = networkReachability else { return }
        SCNetworkReachabilityUnscheduleFromRunLoop(reachability, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue);
    }
    
    // MARK: Handle Reachability Change
    
    func reachabilityCallback(_ flags: SCNetworkReachabilityFlags) {
        let status: ReachabilityStatus = reachabilityStatus(flags)
        guard status != self.networkReachabilityStatus else { return }
        
        if let closure = reachabilityStatusChangedClosure {
            closure(status)
        }
        DispatchQueue.main.async {
            self.lastNetworkReachabilityStatus = self.networkReachabilityStatus
            self.networkReachabilityStatus = status
            NotificationCenter.default.post(name: Notification.Name(rawValue: SSAReachabilityDidChangeNotification), object:self, userInfo: [SSAReachabilityNotificationStatusItem : "\(status)"])
        }
    }
    
    // MARK: Private Functions
    
    fileprivate func reachabilityStatus(_ flags: SCNetworkReachabilityFlags) -> ReachabilityStatus {
        let isReachable: Bool = flags.contains(.reachable)
        let isConnectionRequired: Bool = flags.contains(.connectionRequired)
        let canConnectAutomatically: Bool = flags.contains(.connectionOnDemand) || flags.contains( .connectionOnTraffic)
        let canConnectWithoutUserInteraction = canConnectAutomatically && !flags.contains(.interventionRequired)
        let isNetworkReachable: Bool = (isReachable && (!isConnectionRequired || canConnectWithoutUserInteraction))
        #if os(iOS)
            let isOnWWAN: Bool = flags.contains(SCNetworkReachabilityFlags.isWWAN)
        #endif
        var status: ReachabilityStatus = .unknown
        
        if !isNetworkReachable {
            status = .notReachable
        } else {
            switch reachabilityInformationMode {
            case .simple:
                status = .reachable
            case .advanced:
                #if os(iOS)
                    if isOnWWAN {
                        #if (arch(i386) || arch(x86_64)) && os(iOS)
                            status = .reachableViaWWAN
                        #endif
                    } else {
                        status = .reachableViaWiFi
                    }
                #else
                    status = .ReachableViaWiFi
                #endif
            }
        }
        
        return status
    }
    
    // MARK: Deinitialization
    
    deinit {
        stopMonitoring()
        networkReachability = nil
    }
    
}
