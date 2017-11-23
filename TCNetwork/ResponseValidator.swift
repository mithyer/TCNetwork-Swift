//
//  ResponseValidator.swift
//  TCNetwork
//
//  Created by ray on 2017/11/23.
//  Copyright © 2017年 ray. All rights reserved.
//

import Foundation


class ResponseValidator: RespValidatorProtocol {
    
    required init() {}
    
    var data: Any?
    var success: Bool?
    var successMsg: String?
    var error: NSError?
    var totalNum: UInt?
    var pageIndex: UInt?
    var pageSize: UInt?
    
    var errorFilter: [RespValidatorErrorFilter]? {
        return nil
    }
    
    func validate(_ obj: Any?, fromCache cache: Bool, forRequest request: RequestProtocol, error: NSError?) -> Bool {
        self.success = nil == error && nil != obj
        self.data = obj
        self.error = error
        return self.success!
    }
    
    func reset() {
        self.data = nil
        self.success = false
    }
    
    func promptToShow() -> (prompt: String?, success: Bool?) {
        guard let success = self.success else {
            return (nil, nil)
        }
        if success {
            if let msg = self.successMsg {
                return (msg, success)
            }
        } else {
            guard let error = self.error else {
                return (nil, success)
            }
            guard let filter = self.errorFilter else {
                return (error.localizedDescription, success)
            }
            for f in filter where f.domain == error.domain {
                switch f {
                case .passAllErrors(ofdomain: _):
                    return (error.localizedDescription, success)
                case .passSomeErrors(codes: let codes, ofdomain: _):
                    if codes.index(of: error.code) != nil {
                        return (error.localizedDescription, success)
                    }
                }
            }
        }
        return (nil, success)
    }
}
