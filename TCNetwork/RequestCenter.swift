//
//  RequestCenter.swift
//  TCNetwork
//
//  Created by ray on 2017/11/27.
//  Copyright © 2017年 ray. All rights reserved.
//

import Foundation
import Alamofire

class RequestCenter {
    
    required init(withSessionConfiguration session: URLSessionConfiguration?) {
        self.sessionConfiguration = session
    }
    
    var baseURL: URL?
    
    lazy private var reachabilityManager: Alamofire.NetworkReachabilityManager = Alamofire.NetworkReachabilityManager.init(host: self.baseURL!.absoluteString)!
    
    var networkReachable: Bool {
        return reachabilityManager.isReachable
    }
    var timeoutInterval: TimeInterval = 0
    var acceptableContentTypes: Set<String>?
    
    var sessionConfiguration: URLSessionConfiguration?
    
    lazy var requestManager: Alamofire.SessionManager? = self.dequeueRequestManager(withIdentifier: self.requestManagerPrint)
    
    var urlFilter: RequestUrlFilter?

    static var centers: [String: RequestCenter] = [:]
    class var `default`: RequestCenter {
        let classStr = NSStringFromClass(self)
        if let center = centers[classStr]  {
            return center
        }
        let obj = self.init(withSessionConfiguration: nil)
        centers[classStr] = obj
        return obj
    }
    
    private var _respValidorClass: AnyClass?
    private func responseValidorClass() -> AnyClass {
        return _respValidorClass ?? ResponseValidator.self
    }
    
    func register(responseValidatorClass: AnyClass) {
        _respValidorClass = responseValidatorClass
    }
    
    lazy private var memCache: [String: Any] = [:]
    lazy var cachePathForResponse: String = {
        var path = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first!
        let cls = type(of: self)
        path = path + "\\" + "TCHTTPRequestCache" + (cls == RequestCenter.self ? "" : NSStringFromClass(cls))
        return path
    }()
    
    lazy var securityPolicy: Alamofire.ServerTrustPolicy = .performDefaultEvaluation(validateHost: false)
    
    lazy var poolLock: NSRecursiveLock = {
        let lock = NSRecursiveLock()
        lock.name = "requestPoolLock.TCNetwork.TCKit"
        return lock
    }()
    
    lazy var requestPool = NSMapTable<AnyObject, AnyObject>.init(keyOptions: [.weakMemory, .objectPointerPersonality], valueOptions: [.strongMemory, .objectPointerPersonality])
    
    var requestManagerPrint: String {
        let policyCast = unsafeBitCast(self.securityPolicy, to: Int.self)
        let configCast = nil != self.sessionConfiguration ? unsafeBitCast(self.sessionConfiguration!, to: Int.self) : 0
        var contentTypeCast = 0
        if let types = self.acceptableContentTypes {
            for type in types {
                contentTypeCast ^= type.hashValue
            }
        }
        if policyCast == 0 && configCast == 0 && contentTypeCast == 0 {
            return "default"
        }
        return ("\(policyCast)_" + "\(configCast)_" + "\(contentTypeCast)").md5_16!
    }
    
    private func dequeueRequestManager(withIdentifier identifier: String) ->  Alamofire.SessionManager {
        struct statics {
            static let mngrPool = NSMapTable<NSString, Alamofire.SessionManager>.init(keyOptions: [.strongMemory, .objectPointerPersonality], valueOptions: [.weakMemory, .objectPointerPersonality])
            static let mngrGetQueue = DispatchQueue.init(label: "RequestCenter.dequeueRequestManager")
        }
        var reqMngr: Alamofire.SessionManager?
        statics.mngrGetQueue.sync {
            reqMngr = statics.mngrPool.object(forKey: NSString(string: identifier))
            if nil == reqMngr {
                reqMngr = Alamofire.SessionManager.init(configuration: self.sessionConfiguration!, delegate: SessionDelegate(), serverTrustPolicyManager: ServerTrustPolicyManager.init(policies: [self.baseURL!.absoluteString: self.securityPolicy]))
                if let contentTypes = self.acceptableContentTypes {
                    // FIXME:
                }
                self.reachabilityManager.startListening()
                statics.mngrPool.setObject(reqMngr, forKey: NSString(string: identifier))
            }
        }
        return reqMngr!
    }

}
