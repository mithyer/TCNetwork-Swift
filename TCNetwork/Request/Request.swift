//
//  Request.swift
//  TCNetwork
//
//  Created by ray on 2017/11/24.
//  Copyright © 2017年 ray. All rights reserved.
//

import Foundation

class Request: RequestProtocol, RequestAgentDelegate, TimerDelegate {
    
    required init() {}
    
    convenience init(method: RequestMethod) {
        self.init()
        self.method = method
    }
    deinit {
        self.cancel()
    }
    
    weak var delegate: RequestDelegate?
    var resultHandler: ((_ request: RequestProtocol, _ success: Bool)->())?
    lazy var responseValidator: RespValidatorProtocol? = self.requestAgent?.responseValidator(forRequest: self)
    lazy var identifier: String? = (String(describing: self.observer) + "_" + String(describing: self.apiUrl) + "_" + String(describing: self.method!)).md5_16
    var userInfo: [String: Any]?
    var state: RequestState = .unfire
    var observer: AnyObject? {
        return self.delegate ?? self
    }
    // MARK: - build request
    var apiUrl: String?
    var baseUrl: String?
    var parameters: Any?
    var timeoutInterval: Double = 30
    var method: RequestMethod?
    var overrideIfImpact: Bool = true
    var ignoreParamFilter: Bool = false
    var customHeaders: [String: String]?
    var responseObject: Any? {
        return nil != self.requestTask ? self.rawResponseObject : nil
    }
    var isRequestingNetwork: Bool {
        return self.state == .network
    }
    // MARK: - timer
    var timerPolicy: TimerPolicy? {
        get {
            return _timerPolicy
        }
        set(new) {
            if let newPolicy = new {
                if let policy = _timerPolicy, newPolicy !== policy {
                    policy.delegate = nil
                    newPolicy.delegate = self
                }
                _timerPolicy = newPolicy
            }
        }
    }
    // MARK: - Upload / download
    var streamPolicy: StreamPolicy? {
        get {
            return _streamPolicy
        }
        set(new) {
            if let newPolicy = new {
                if let policy = _streamPolicy, newPolicy !== policy {
                    policy.request = nil
                    newPolicy.request = self
                }
                _streamPolicy = newPolicy
            }
        }
    }
    // MARK: - Custom
    // set nonull to ignore requestUrl, argument, requestMethod, serializerType
    var customUrlRequest: URLRequest?
    
    // MARK: - Cache
    var cachePolicy: CachePolicy?
    var isForceStart: Bool = false
    
    var requestTask: URLSessionTask?
    weak var requestAgent: RequestAgent?
    var rawResponseObject: Any?

    /**
     @brief    start a http request with checking available cache,
     if cache is available, no request will be fired.
     
     @param error [OUT] param invalid, etc...
     
     */
    
    
    func start() throws -> Bool {
        guard let requestAgent = self.requestAgent, !_isCancelled else {
            return false
        }
        if self.method == .download && nil != self.timerPolicy {
            throw NSException(name: NSExceptionName(String(reflecting: self)), reason: "download task can not be polling")
        }
        if let timerPolicy = self.timerPolicy, timerPolicy.needStartTimer {
            let res = timerPolicy.forward()
            if res {
                // !!!: add to pool to prevent self dealloc before polling fired
                requestAgent.add(requestToPool: self)
            }
        }
        return true
    }
    
    func start(withResult callback: @escaping (_ request: RequestProtocol, _ success: Bool) -> ()) throws -> Bool {
        self.resultHandler = callback
        return try self.start()
    }
    
    func canStart() -> (can: Bool, error: NSError?) {
        if let agent = self.requestAgent {
            return agent.canAdd(request: self)
        }
        return (false, nil)
    }
    // delegate, resulteBlock always called, even if request was cancelled.
    func cancel() {
        if let timerPolicy = self.timerPolicy, !self._isCancelled , !timerPolicy.isValid {
            let isTicking = timerPolicy.isTicking
            timerPolicy.invalidate()
            if nil == self.requestAgent || self.requestTask?.state == .completed {
                _isCancelled = true
                if isTicking {
                    if let validator = self.responseValidator {
                        validator.reset()
                        validator.error = NSError.init(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: [NSLocalizedFailureReasonErrorKey: "timer request cancelled", NSLocalizedDescriptionKey: "timer request cancelled"])
                    }
                    self.requestResponded(isValid: false, clean: true)
                }
                return
            }
        }
        if nil == self.requestTask || self.requestTask!.state == .canceling || self.requestTask!.state == .completed {
            _isCancelled = true
            return
        }
        _isCancelled = true
        if let streamPolicy = self.streamPolicy, let requestTask = self.requestTask as? URLSessionDownloadTask, self.method == .download, streamPolicy.shouldResumeDownload {
            requestTask.cancel(byProducingResumeData: { (resumeData) in
                // not in main thread
            })
        } else {
            self.requestTask?.cancel()
        }
    }


    
    /**
     @brief    fire a request regardless of cache available
     if cache is available, callback then fire a request.
     
     @param error [OUT] error description
     
     @return return value description
     */
    func cachedResponse(byForce force: Bool, result: @escaping (_ response: Any?, _ state: CachedRespState) -> ()) {}

    // MARK: RequestAgentDelegate
    
    func requestResponded(isValid: Bool, clean: Bool) {

        #if TC_IOS_PUBLISH
            if !isValid {
                print("\(self)\n \nError: \(self.responseValidator?.error)")
            }
        #endif
        
        let closure = {
            var needForward = false
            if let timerPolicy = self.timerPolicy {
                needForward = timerPolicy.checkForwardForRequest(success: isValid)
            }
            if let delegate = self.delegate {
                delegate.process(request: self, success: isValid)
            }
            if let handler = self.resultHandler {
                handler(self, isValid)
            }
            if clean && !needForward {
                self.resultHandler = nil
                self.requestAgent?.remove(requestFromPool: self)
            } else if needForward {
                self.state = .unfire
                self.requestTask = nil
                self.rawResponseObject = nil
                let _ = self.timerPolicy?.forward()
            }
        }
        
        Thread.isMainThread ? closure() : DispatchQueue.main.sync(execute: closure)
    }
    
    
    // MARK: - TCHTTPTimerDelegate
    
    func timerRequest(forPolicy policy: TimerPolicy) -> Bool {
        let res = try? self.start()
        return res ?? false
    }
    
    // MARK: - Cache
    func forceStart() throws -> Bool {
        return try self.start()
    }
    
    func description() -> String {
        let request = self.requestTask?.originalRequest
        let url = request?.url?.absoluteString ?? ""
        let fields = request?.allHTTPHeaderFields ?? [:]
        let body = request?.httpBody != nil ? String.init(data: (request?.httpBody)!, encoding: .utf8)! : ""
        let responseObj = self.responseObject ?? ""
        return "🌍🌍🌍 \(type(of: self)): \(url)\nhead:\(fields)\nparam: \(body)\nfrom cache: (\(self.cachePolicy?.isDataFromCache ?? false)\nresponse: \(responseObj)"
    }

    
    // MARK: private property
    
    private var _isCancelled: Bool = false
    private var _streamPolicy :StreamPolicy? = nil
    private var _timerPolicy :TimerPolicy? = nil
}
