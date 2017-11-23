//
//  RequestAgent.swift
//  TCNetwork-Demo
//
//  Created by ray on 2017/11/21.
//  Copyright © 2017年 ray. All rights reserved.
//

import Foundation

protocol RequestAgent: class {
    func addToPool(request: RequestProtocol)
    func removeFromPool(request: RequestProtocol)
    
    func canAdd(request: RequestProtocol) -> (can: Bool, error: NSError?)
    func add(request: RequestProtocol) throws -> Bool
    func buildRequestUrl(forRequest request: RequestProtocol)
    
    // cache
    var cachePathForResponse: String { get }
    
    //func storeCachedResponse(response: AnyObject, forCachePolicy cachePolicy: )
    
}

