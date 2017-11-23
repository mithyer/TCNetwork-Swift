//
//  CachePolicy.swift
//  TCNetwork
//
//  Created by ray on 2017/11/23.
//  Copyright © 2017年 ray. All rights reserved.
//

import Foundation

class CachePolicy {
    required init() {}
    
    enum TimeoutIntervalType {
        case expired(after: TimeInterval)
        case neverExpired
    }
    
    weak var request: (RequestProtocol & RequestAgentDelegate)?
    var cacheResponse: Any?
    
    var shouldIgnoreCache: Bool = false
    var shouldCacheResponse: Bool = true
    var shouldCacheEmptyResponse: Bool = true // empty means: empty string, array, dictionary
    var cacheTimeoutInterval: TimeoutIntervalType = .expired(after: 0)
    
    var shouldExpiredCacheValid: Bool = false
    
    var isCacheValid: Bool {
        return self.cacheState == .valid
    }

    var cacheData: Date? {
        guard let cacheFilePath = self.cacheFilePath else {
            return nil
        }
        switch self.cacheState {
        case .expired, .valid:
            return (try? FileManager.default.attributesOfItem(atPath: cacheFilePath)[FileAttributeKey.modificationDate]) as? Date
        default:
            return nil
        }
    }
    
    var isDataFromCache: Bool {
        return nil != self.cacheResponse
    }
    
    var cacheState: CachedRespState {
        guard let path = self.cacheFilePath else {
            return .none
        }
        var isDir: ObjCBool = false
        let fileMgr = FileManager.default
        if !fileMgr.fileExists(atPath: path, isDirectory: &isDir) || isDir.boolValue {
            return .none
        }
        guard let attributes = try? fileMgr.attributesOfItem(atPath: path), attributes.count > 0 else {
            return .expired
        }
        guard let timeIntervalSinceNow = (attributes[FileAttributeKey.modificationDate] as? Date)?.timeIntervalSinceNow, timeIntervalSinceNow < 0 else {
            return .expired
        }
        if ({
            switch self.cacheTimeoutInterval {
            case .expired(after: let interval) where -timeIntervalSinceNow < interval:
                return true
            case .neverExpired:
                return true
            default:return false
            }}()) {
            if self.request?.method == .download && !fileMgr.fileExists(atPath: path) {
                return .none
            }
            return .valid
        }
        return .expired
    }
    
    func setCachePathFilter(withRequestParameters parameters:[String: Any], sensitiveData: AnyObject) {
        _parametersForCachePathFilter = parameters
        _sensitiveDataForCachePathFilter = sensitiveData
    }
    
    var cacheFileName: String? {
        guard let parametersForCachePathFilter = _parametersForCachePathFilter, let sensitiveDataForCachePathFilter = _sensitiveDataForCachePathFilter else {
            return _cacheFileName
        }
        var requestUrl: String?
        if let requestAgent = self.request?.requestAgent {
            requestUrl = requestAgent.buildRequestUrl(forRequest: self.request!).absoluteString
        } else {
            requestUrl = self.request?.apiUrl
        }
        
        let cacheKey: String = "Method:\((self.request?.method)!), RequestUrl:\(requestUrl!), Parames:\(parametersForCachePathFilter), Sensitive:\(sensitiveDataForCachePathFilter)"
        _parametersForCachePathFilter = nil
        _sensitiveDataForCachePathFilter = nil
        _cacheFileName = cacheKey.md5_32
        return _cacheFileName
    }
    
    var cacheFilePath: String? {
        if let method = self.request?.method, method == .download {
            return self.request?.streamPolicy?.downloadDestinationPath
        }
        var path: String?
        if let requestAgent = self.request?.requestAgent {
            path = requestAgent.cachePathForResponse
        }
        if nil == path {
            path = NSTemporaryDirectory() + "\\TCHTTPCache.TCNetwork.TCKit"
        }
        if nil != path && nil != self.cacheFileName && self.createDiretory(forCachePath: path!) {
            return path! + "\\" + self.cacheFileName!
        }
        return nil
    }
    
    var shouldWriteToCache: Bool {
        switch self.cacheTimeoutInterval {
        case .expired(after: let interval) where interval == 0:
            return self.request?.method != .download && self.shouldCacheResponse && self.validateResponseObjectForCache
        default:
            return false
        }
    }
    
    private var _parametersForCachePathFilter: [String: Any]?
    private var _sensitiveDataForCachePathFilter: AnyObject?
    private var _cacheFileName: String?
    
    private var validateResponseObjectForCache: Bool {
        guard let responseObject = self.request?.responseObject else {
            return false
        }
        if !self.shouldCacheResponse {
            if let dic = responseObject as? [String: Any] {
                return dic.count > 0
            }
            if let array = responseObject as? [Any] {
                return array.count > 0
            }
            guard let _ = responseObject as? String else {
                return false
            }
        }
        return true
    }
    
    private func createDiretory(forCachePath path: String) -> Bool {
        let fileMgr = FileManager.default
        var isDir: ObjCBool = false
        if fileMgr.fileExists(atPath: path, isDirectory: &isDir) {
            if isDir.boolValue {
                return true
            } else {
                try? fileMgr.removeItem(atPath: path)
            }
        }
        if let _ = try? fileMgr.createDirectory(atPath: path, withIntermediateDirectories: true) {
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var url = URL.init(fileURLWithPath: path)
            try? url.setResourceValues(values)
            return true
        }
        return false
    }
}
