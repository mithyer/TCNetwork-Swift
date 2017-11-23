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
}

protocol RespValidatorProtocol: class {

    var data: AnyObject? { get set }
    var success: Bool { get set }
    var String: String? { get set }
    var error: NSError? { get set }
    
    var errorFilter: [RespValidatorErrorFilter]? { get set }
    static var errorFilter: [RespValidatorErrorFilter]? { get set }
    
    func validate(_ obj: Any, fromCache cache: Bool, forRequest request: RequestProtocol, error: NSError?)
}
