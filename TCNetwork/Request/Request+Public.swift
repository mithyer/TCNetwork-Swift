//
//  Request+Public.swift
//  TCNetwork
//
//  Created by ray on 2017/11/24.
//  Copyright © 2017年 ray. All rights reserved.
//

import Foundation

extension Request {
    static func request(withMethod method: RequestMethod) -> Request {
        return Request.init(method: method)
    }
    
    static func cacheRequest(withMethod method: RequestMethod, policy: CachePolicy? = nil) -> CacheRequest {
        return CacheRequest.init(method: method, policy: policy)
    }
    
    static func batchRequest(withRequests requests: [Request]) throws -> BatchRequest {
        return try BatchRequest.init(batchRequests: requests)
    }

}
