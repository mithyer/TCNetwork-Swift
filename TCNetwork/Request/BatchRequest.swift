//
//  BatchRequest.swift
//  TCNetwork
//
//  Created by ray on 2017/11/27.
//  Copyright © 2017年 ray. All rights reserved.
//

import Foundation

class BatchRequest: Request, RequestDelegate {

    
    override private init() {
        super.init()
    }
    
    convenience init(batchRequests: [Request]) throws {
        self.init()
        
        for request in batchRequests {
            if nil != request.timerPolicy && request.timerPolicy?.timerType != .delay {
                throw NSException.init(name: NSExceptionName.init(NSStringFromClass(type(of: self))), reason: "request must be none empty and conform to TCHTTPRequest protocol !")
            }
        }
        self.batchRequests = batchRequests
    }
    
    var batchRequests: [Request]?
    var continueAfterSubRequestFailed: Bool = false
    
    override func start() throws -> Bool {
        guard let requestAgent = self.requestAgent else {
            return false
        }
        if nil != self.timerPolicy && .delay != self.timerPolicy?.timerType {
            return false
        }
        
        self.state = .network
        requestAgent.add(requestToPool: self)
        
        var res = true
        for request in self.batchRequests! {
            if nil == request.requestAgent {
                request.requestAgent = self.requestAgent
            }
            request.observer = self
            request.delegate = self
            
            // ignore expired cache
            if nil != request.cachePolicy {
                request.cachePolicy?.shouldExpiredCacheValid = false
            }
            do {
                if !(try super.start()) {
                    res = false
                    break
                }
            } catch let error {
                print(error)
            }
        }
        if !res {
            self.cancel()
            self.state = .finished
            requestAgent.remove(requestFromPool: self)
            
            throw NSError.init(domain: NSStringFromClass(type(of: self)), code: -1, userInfo: [NSLocalizedFailureReasonErrorKey: "start batch request failed.",
                                                                                               NSLocalizedDescriptionKey: "any bacth request item start failed."])
        }
        return res
    }
    
    override func cancel() {
        if self._isCancelled || self.state == .unfire || self.state == .finished {
            return
        }
        _isCancelled = true
        guard let requests = self.batchRequests else {
            return
        }
        for request in requests {
            request.delegate = nil
            request.resultHandler = nil
            request.streamPolicy?.constructingBodyClosure = nil
            request.cancel()
        }
    }
    
    // MARK: RequestDelegate
    
    func process(request: RequestProtocol, success: Bool) {
        _finishDic[request as! Request] = success
        if success || self.continueAfterSubRequestFailed {
            let res = self.allRequestFinished()
            if res.finished {
                // called in next runloop to avoid resultBlock = nil of sub request;
                DispatchQueue.main.async {
                    self.requestCallback(isValid: res.successed)
                }
            }
        } else {
            self.cancel()
            self.requestCallback(isValid: false)
        }
    }
    
    static func process(request: RequestProtocol, success: Bool) {
    
    }
    
    private func requestCallback(isValid: Bool) {
        self.state = .finished
        self.requestResponded(isValid: isValid, clean: true)
    }
    
    private func allRequestFinished() -> (finished: Bool, successed: Bool) {
        var successed = false
        var finished = false
        if let batchRequests = self.batchRequests {
            for request in batchRequests {
                guard let res = _finishDic[request] else {
                    finished = false
                    break
                }
                successed = successed && res
            }
        }
        successed = successed && finished
        return (finished, successed)
    }
    
    private var _isCancelled: Bool = false
    lazy private var _finishDic: [Request: Bool] = [:]
    

}
