//
//  RequestAgentDelegate.swift
//  TCNetwork-Demo
//
//  Created by ray on 2017/11/21.
//  Copyright © 2017年 ray. All rights reserved.
//

import Foundation

protocol RequestAgentDelegate {
    
    var requestTask: URLSessionTask? { get set }
    weak var requestAgent: RequestAgent? { get set }
    var rawResponseObject: AnyObject? { get set }
    
    func requestResponded(isValid: Bool, clean: Bool)
}
