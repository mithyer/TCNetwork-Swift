//
//  RequestProtocol.swift
//  TCNetwork-Demo
//
//  Created by ray on 2017/11/21.
//  Copyright © 2017年 ray. All rights reserved.
//

import Foundation

enum RequestState {
    case unfire, network, finished
}

enum CachedRespState {
    case none, valid, expired
}

enum RequestMethod {
    case get, post, postJSON, head, put, delete, patch, download
}

protocol RequestProtocol: class {
    
    weak var delegate: RequestDelegate? { get set }
    var resultHandler: ((_ request: RequestProtocol, _ success: Bool)->())? { get set }
    var responseValidator: RespValidatorProtocol? { get set }
    
    var identifier: String? { get set }
    var userInfo: [String: Any]? { get set }
    var state: RequestState { get set }
    var observer: AnyObject? { get }
    
    /**
     @brief    start a http request with checking available cache,
     if cache is available, no request will be fired.
     
     @param error [OUT] param invalid, etc...
     
     */
    func start() throws -> Bool
    func start(withResult callback: @escaping (_ request: RequestProtocol, _ success: Bool) -> ()) throws -> Bool
    func canStart() -> (can: Bool, error: NSError?)
    // delegate, resulteBlock always called, even if request was cancelled.
    func cancel()
    var isRequestingNetwork: Bool { get }
    
    // MARK: - build request
    var apiUrl: String? { get set }
    var baseUrl: String? { get set }
    var parameters: Any? { get set }
    var timeoutInterval: Double { get set }
    var method: RequestMethod? { get set }
    
    var overrideIfImpact: Bool { get set }
    var ignoreParamFilter: Bool { get set }

    var customHeaders: [String: String]? { get set }
    
    var responseObject: Any? { get }
    
    // MARK: - timer
    
    var timerPolicy: TimerPolicy? { get set }
    
    // MARK: - Upload / download
    var streamPolicy: StreamPolicy? { get set }
    
    // MARK: - Custom
    // set nonull to ignore requestUrl, argument, requestMethod, serializerType
    var customUrlRequest: URLRequest? { get set }

    // MARK: - Cache
    var cachePolicy: CachePolicy? { get }
    var isForceStart: Bool {get}
    
    /**
     @brief    fire a request regardless of cache available
     if cache is available, callback then fire a request.
     
     @param error [OUT] error description
     
     @return return value description
     */
    func forceStart() throws -> Bool
    func cachedResponse(byForce force: Bool, result: @escaping (_ response: Any?, _ state: CachedRespState) -> ())
}

protocol RequestDelegate: class {
    func process(request: RequestProtocol, success: Bool)
    static func process(request: RequestProtocol, success: Bool)
}
