//
//  RespValidatorProtocol.swift
//  TCNetwork-Demo
//
//  Created by ray on 2017/11/21.
//  Copyright © 2017年 ray. All rights reserved.
//

import Foundation

enum RespValidatorErrorFilter {
    case passAllErrors(ofdomain: String)
    case passSomeErrors(codes: [Int], ofdomain: String)
    
    var domain: String {
        switch self {
        case .passAllErrors(ofdomain: let domain):
            return domain
        case .passSomeErrors(codes: _, ofdomain: let domain):
            return domain
        }
    }
}

protocol RespValidatorProtocol: class {

    var data: Any? { get set }
    var success: Bool? { get set }
    var successMsg: String? { get set }
    var error: NSError? { get set }
    
    var errorFilter: [RespValidatorErrorFilter]? { get }
    
    func reset()
    func promptToShow() -> (prompt: String?, success: Bool?)
    
    var totalNum: UInt? { get set }
    var pageIndex: UInt? { get set }
    var pageSize: UInt? { get set }

    func validate(_ obj: Any?, fromCache cache: Bool, forRequest request: RequestProtocol, error: NSError?) -> Bool
}
