//
//  RequestUrlFilter.swift
//  TCNetwork
//
//  Created by ray on 2017/11/27.
//  Copyright © 2017年 ray. All rights reserved.
//

import Foundation

protocol RequestUrlFilter {
    
    static func filteredUrl(forUrl url: String) -> String
    static func filteredParam(forParam param: [String: Any]) -> [String: Any]?
    static func filteredParam(forParam param: [String]) -> [String]?

    func filteredParam(forParam param: [String: Any]) -> [String: Any]?
    func filteredParam(forParam param: [String]) -> [String]?
    
}
