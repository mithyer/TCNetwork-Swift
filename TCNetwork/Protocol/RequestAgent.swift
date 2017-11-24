//
//  RequestAgent.swift
//  TCNetwork-Demo
//
//  Created by ray on 2017/11/21.
//  Copyright © 2017年 ray. All rights reserved.
//

import Foundation

protocol RequestAgent: class {
    func add(requestToPool request: RequestProtocol)
    func remove(requestFromPool request: RequestProtocol)
    
    func canAdd(request: RequestProtocol) -> (can: Bool, error: NSError?)
    func add(request: RequestProtocol) throws -> Bool
    func buildRequestUrl(forRequest request: RequestProtocol) -> URL
    
    // cache
    var cachePathForResponse: String { get }
    
    func storeCachedResponse(response: Any, forCachePolicy cachePolicy: CachePolicy, finished: () -> ())
    func cacheResponse(forRequest request: RequestProtocol, result: (_ response: Any?) -> ())
    
    func responseValidator(forRequest request: RequestProtocol) -> RespValidatorProtocol
    
    func requests(forObserver observer: AnyObject) -> [RequestProtocol]
    func request(forObserver observer: AnyObject, identifer: AnyObject) -> RequestProtocol
}

