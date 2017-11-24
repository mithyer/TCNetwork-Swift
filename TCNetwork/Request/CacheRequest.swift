//
//  CacheRequest.swift
//  TCNetwork
//
//  Created by ray on 2017/11/24.
//  Copyright © 2017年 ray. All rights reserved.
//

import UIKit

class CacheRequest: Request {
    
    convenience init(method: RequestMethod, policy: CachePolicy? = nil) {
        self.init()
        self.cachePolicy = policy ?? CachePolicy()
        self.cachePolicy?.request = self
        self.state = .unfire
    }
    
    override var state: RequestState {
        didSet(state) {
            if state == .finished {
                self.requestResponseReset()
            }
        }
    }
    
    override var responseObject: Any? {
        return self.cachePolicy?.cacheResponse ?? super.responseObject
    }
    
    private func requestResponseReset() {
        self.cachePolicy?.cacheResponse = nil
    }
    
    override func requestResponded(isValid: Bool, clean: Bool) {
        self.requestResponseReset()
        if  isValid,
            let requestAgent = self.requestAgent,
            let cachePolicy = self.cachePolicy,
            let respObj = self.responseObject,
            cachePolicy.shouldIgnoreCache {
                requestAgent.storeCachedResponse(response: respObj, forCachePolicy: cachePolicy, finished: {
                    super.requestResponded(isValid: isValid, clean: clean)
                })
        } else {
            super.requestResponded(isValid: isValid, clean: clean)
        }
    }
    
    override func cachedResponse(byForce force: Bool, result: @escaping (Any?, CachedRespState) -> ()) {
        let cacheState: CachedRespState = self.cachePolicy!.cacheState
        if cacheState == .valid || (force && cacheState != .none) {
            self.requestAgent?.cacheResponse(forRequest: self, result: { [weak self] (response) in
                guard let sSelf = self, let respValidator = sSelf.responseValidator else {
                    return
                }
                let _ = respValidator.validate(response, fromCache: true, forRequest: sSelf, error: nil)
                result(response, cacheState)
            })
            return
        }
        result(nil, cacheState)
    }
    
    private func cacheRequestCallbackWithoutFiring(notFire: Bool) {
        let isValid = self.responseValidator?.validate(self.responseObject, fromCache: true, forRequest: self, error: nil) ?? true
        if notFire || isValid {
            super.requestResponded(isValid: isValid, clean: notFire)
        }
    }
    
    private func callSuperStart() throws -> Bool {
        return try super.start()
    }
    
    override func start() throws -> Bool {
        if self.isForceStart {
            return try self.forceStart()
        }
        let cachePolicy = self.cachePolicy!
        if cachePolicy.shouldIgnoreCache || nil != self.timerPolicy {
            return try super.start()
        }
        
        if cachePolicy.cacheState == .valid || (cachePolicy.shouldExpiredCacheValid && state != .none) {
            // !!!: add to pool to prevent self dealloc before cache respond
            self.requestAgent?.add(requestToPool: self)
            self.requestAgent?.cacheResponse(forRequest: self, result: { [weak self] (response) in
                if nil == response {
                    let _ = try? self?.callSuperStart()
                    return
                }
                guard let sSelf = self else {
                    return
                }
                if cachePolicy.cacheState == .valid {
                    DispatchQueue.main.async {
                        sSelf.cacheRequestCallbackWithoutFiring(notFire: true)
                    }
                } else if cachePolicy.shouldExpiredCacheValid {
                    DispatchQueue.main.async {
                        if let res = try? sSelf.callSuperStart() {
                            sSelf.cacheRequestCallbackWithoutFiring(notFire: res)
                        }
                    }
                }
            })
            return cachePolicy.cacheState == .valid ? true : super.canStart().can
        }
        return try super.start()
    }
    
    override func forceStart() throws -> Bool {
        self.isForceStart = true
        let cachePolicy = self.cachePolicy!
        if !cachePolicy.shouldIgnoreCache && nil == self.timerPolicy {
            let state = cachePolicy.cacheState
            if state == .valid || (state == .expired && cachePolicy.shouldExpiredCacheValid) {
                // !!!: add to pool to prevent self dealloc before cache respond
                let _ = try self.requestAgent?.add(request: self)
                self.requestAgent?.cacheResponse(forRequest: self, result: { [weak self] (response) in
                    guard let sSelf = self else {
                        return
                    }
                    DispatchQueue.main.async {
                        if let _ = response {
                            sSelf.cacheRequestCallbackWithoutFiring(notFire: !sSelf.canStart().can)
                        }
                        let _ = try? sSelf.callSuperStart()
                    }
                })
                let res = self.canStart()
                if let error = res.error {
                    throw error
                } else {
                    return res.can
                }
            }
        }
        return try super.start()
    }
}
