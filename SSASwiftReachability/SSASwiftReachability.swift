//
//  SSASwiftReachability.swift
//  SSASwiftReachability
//
//  Created by Sebastian Andersen on 05/02/15.
//  Copyright (c) 2015 SebastianAndersen. All rights reserved.
//

import SystemConfiguration
import Foundation

let SSAReachabilityDidChangeNotification = "ReachabilityChangedNotification"
let SSAReachabilityNotificationStatusItem = "ReachabilityNotificationStatusItem"

func callback(target: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutablePointer<Void>) {
    let reachability = Unmanaged<SSASwiftReachability>.fromOpaque(COpaquePointer(info)).takeUnretainedValue()
    
    dispatch_async(dispatch_get_main_queue()) {
        reachability.reachabilityCallback(flags)
    }
}

public class SSASwiftReachability {
    
    typealias ReachabilityStatusChangedClosure = (ReachabilityStatus) -> ()
    
// MARK: Public Enums
    
    enum ReachabilityStatus: Int {
        case Unknown = -1
        case NotReachable = 0
        case ReachableViaWWAN = 1
        case ReachableViaWiFi = 2
        case Reachable = 3
        
        var description : String {
            get {
                switch(self) {
                case .Unknown:
                    return "Unknown"
                case .NotReachable:
                    return "Not Reachable"
                case .ReachableViaWWAN:
                    return "Reachable Via WWAN"
                case .ReachableViaWiFi:
                    return "Reachable Via WiFi"
                case .Reachable:
                    return "Reachable"
                }
            }
        }
    }
    
    enum ReachabilityAssociation: Int {
        case ForAddress = 1
        case ForAddressPair = 2
        case ForName = 3
    }
    
    enum ReachabilityInformationMode: Int {
        case Simple = 1
        case Advanced = 2
    }
    
// MARK: Public Variables
    
    var networkReachabilityStatus: ReachabilityStatus = .Unknown
    var reachabilityAssociation: ReachabilityAssociation = .ForName
    var reachabilityInformationMode: ReachabilityInformationMode = .Simple
    
    var currentReachabilityString: String {
        return networkReachabilityStatus.description
    }
    
// MARK: Public Optional Variables
    
    var reachabilityStatusChangedClosure: ReachabilityStatusChangedClosure?
    
// MARK: Public Class Variables
    
    class var zeroAdress: sockaddr_in {
        var address: sockaddr_in = sockaddr_in(sin_len: __uint8_t(0), sin_family: sa_family_t(0), sin_port: in_port_t(0), sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        address.sin_len = UInt8(sizeofValue(address))
        address.sin_family = sa_family_t(AF_INET)
        
        return address
    }
    
// MARK: Private Variables
    
    private var networkReachability: SCNetworkReachabilityRef?
    private var lastNetworkReachabilityStatus: ReachabilityStatus = .Unknown
    
// MARK: Singleton
    
    static let sharedManager: SSASwiftReachability? = SSASwiftReachability.managerForAddress(SSASwiftReachability.zeroAdress)
    
// MARK: Initialization
    
    private init(reachabilityRef: SCNetworkReachability, reachabilityAssociation: ReachabilityAssociation) {
        self.networkReachability = reachabilityRef
        self.reachabilityAssociation = reachabilityAssociation
    }
    
// MARK: Public Class Functions
    
    class func managerForDomain(domain: String) -> SSASwiftReachability? {
        let reachabilityRef: SCNetworkReachability? = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, (domain as NSString).UTF8String)
        return SSASwiftReachability(reachabilityRef: reachabilityRef!, reachabilityAssociation: .ForName)
    }
    
    class func managerForAddress(var address: sockaddr_in) -> SSASwiftReachability? {
        let reachabilityRef = withUnsafePointer(&address) {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
        }
        
        return SSASwiftReachability(reachabilityRef: reachabilityRef!, reachabilityAssociation: .ForAddress)
    }
    
// MARK: Public Functions
    
    func isReachable() -> Bool {
        return networkReachabilityStatus == .Reachable || networkReachabilityStatus == .ReachableViaWWAN || networkReachabilityStatus == .ReachableViaWiFi
    }
    
    func isReachableViaWWAN() -> Bool {
        return networkReachabilityStatus == .ReachableViaWWAN
    }
    
    func isReachableViaWiFi() -> Bool {
        return networkReachabilityStatus == .ReachableViaWiFi
    }
    
// MARK: Start Monitoring For Reachability Changes
    
    func startMonitoring() {
        stopMonitoring()
        guard let reachability = networkReachability else { return }
            
        let statusClosure: ReachabilityStatusChangedClosure = { [weak self] status in
            self?.networkReachabilityStatus = status
        }
        
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = UnsafeMutablePointer(Unmanaged.passUnretained(self).toOpaque())
        
        SCNetworkReachabilitySetCallback(reachability, callback, &context)
        SCNetworkReachabilityScheduleWithRunLoop(reachability, CFRunLoopGetMain(), kCFRunLoopCommonModes)
        
        // Get Initial Reachability Status
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags()
            SCNetworkReachabilityGetFlags(reachability, &flags)
            let status: ReachabilityStatus = self.reachabilityStatus(flags)
            
            dispatch_async(dispatch_get_main_queue()) {
                statusClosure(status)
                NSNotificationCenter.defaultCenter().postNotificationName(SSAReachabilityDidChangeNotification, object:self, userInfo: [SSAReachabilityNotificationStatusItem : "\(status)"])
            }
        }
    }
    
// MARK: Stop Monitoring For Reachability Changes
    
    func stopMonitoring() {
        guard let reachability = networkReachability else { return }
        SCNetworkReachabilityUnscheduleFromRunLoop(reachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    }
    
// MARK: Handle Reachability Change
    
    func reachabilityCallback(flags: SCNetworkReachabilityFlags) {
        let status: ReachabilityStatus = reachabilityStatus(flags)
        guard status != self.networkReachabilityStatus else { return }
        
        if let closure = reachabilityStatusChangedClosure {
            closure(status)
        }
        dispatch_async(dispatch_get_main_queue()) {
            self.lastNetworkReachabilityStatus = self.networkReachabilityStatus
            self.networkReachabilityStatus = status
            NSNotificationCenter.defaultCenter().postNotificationName(SSAReachabilityDidChangeNotification, object:self, userInfo: [SSAReachabilityNotificationStatusItem : "\(status)"])
        }
    }
    
// MARK: Private Functions
    
    private func reachabilityStatus(flags: SCNetworkReachabilityFlags) -> ReachabilityStatus {
        let isReachable: Bool = flags.contains(.Reachable)
        let isConnectionRequired: Bool = flags.contains(.ConnectionRequired)
        let canConnectAutomatically: Bool = flags.contains(.ConnectionOnDemand) || flags.contains( .ConnectionOnTraffic)
        let canConnectWithoutUserInteraction = canConnectAutomatically && !flags.contains(.InterventionRequired)
        let isNetworkReachable: Bool = (isReachable && (!isConnectionRequired || canConnectWithoutUserInteraction))
#if os(iOS)
        let isOnWWAN: Bool = flags.contains(SCNetworkReachabilityFlags.IsWWAN)
#endif
        var status: ReachabilityStatus = .Unknown
        
        if !isNetworkReachable {
            status = .NotReachable
        } else {
            switch reachabilityInformationMode {
            case .Simple:
                status = .Reachable
            case .Advanced:
#if os(iOS)
                if isOnWWAN {
                    #if (arch(i386) || arch(x86_64)) && os(iOS)
                        status = .ReachableViaWWAN
                    #endif
                } else {
                    status = .ReachableViaWiFi
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