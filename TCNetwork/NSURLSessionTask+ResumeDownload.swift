//
//  NSURLSessionTask+ResumeDownload.swift
//  TCNetwork
//
//  Created by ray on 2017/11/22.
//  Copyright © 2017年 ray. All rights reserved.
//

import Foundation

extension URLSessionTask {
    static let load: Bool = {
        
        return true
    }()
    
    static private var tc_resumeIdentifier_key: Int = 0
    var tc_resumeIdentifier: String? {
        get {
            return objc_getAssociatedObject(self, &URLSessionTask.tc_resumeIdentifier_key) as? String
        }
        set(new) {
            objc_setAssociatedObject(self, &URLSessionTask.tc_resumeIdentifier_key, new, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    static private var tc_resumeCacheDirectory_key: Int = 0
    var tc_resumeCacheDirectory: String? {
        get {
            return objc_getAssociatedObject(self, &URLSessionTask.tc_resumeCacheDirectory_key) as? String
        }
        set(new) {
            objc_setAssociatedObject(self, &URLSessionTask.tc_resumeCacheDirectory_key, new, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    static var enabledClasses: [NSObject.Type] = []
    static let lock: DispatchSemaphore = DispatchSemaphore.init(value: 1)
    func tc_makePersistentResumeCapable() -> Bool {
        guard self is URLSessionDownloadTask else {
            return false
        }
        let selfType: NSObject.Type = type(of: self)
        URLSessionTask.lock.wait()
        if !(URLSessionTask.enabledClasses.contains { (obj) -> Bool in
            return obj == selfType
        }) {
            selfType.tc_swizzle(name: #selector(URLSessionDownloadTask.cancel(byProducingResumeData:)))
            URLSessionTask.enabledClasses.append(selfType)
        }
        URLSessionTask.lock.signal()
        return true
    }
    
    func tc_cancel(byProducingResumeData completionHandler: @escaping (Data?) -> Swift.Void) {
        guard let _ = self.tc_resumeCacheDirectory else {
            self.tc_cancel(byProducingResumeData: completionHandler)
            return
        }
        self.tc_cancel {[weak self] (data) in
            guard let sSelf = self else {
                return
            }
            let closure = {
                guard let resumeData = data else {
                    return
                }
                autoreleasepool {
                    guard let path = sSelf.tc_resumeCachePath else {
                            return
                    }
                    let url = URL.init(fileURLWithPath: path)
                    guard let _ = try? resumeData.write(to: url, options: .atomic) else {
                        return
                    }
                    guard !URLSessionTask.tc_isTmpResumeCache(resumeDirectory: sSelf.tc_resumeCacheDirectory!),
                        let tmpDownloadFile: String = type(of: sSelf).tc_resumeInfoTempFileName(for: resumeData),
                        let resumeCacheDirectory = sSelf.tc_resumeCacheDirectory else {
                            return
                    }
                    let cachePath = NSString(string: resumeCacheDirectory).appendingPathComponent(NSString(string: tmpDownloadFile).lastPathComponent)
                    try? FileManager.default.removeItem(atPath: cachePath)
                    try? FileManager.default.moveItem(atPath: tmpDownloadFile, toPath: cachePath)
                }
            }
            if Thread.isMainThread {
                DispatchQueue.global().async {
                    closure()
                    completionHandler(data)
                }
            } else {
                closure()
                completionHandler(data)
            }
        }
    }
    
    private static func tc_resumeCachePath(withDirectory subpath: String, identifier: String) -> String {
        return subpath + identifier.md5_32!
    }
    
    private static func tc_isTmpResumeCache(resumeDirectory: String) -> Bool {
        return resumeDirectory.hasPrefix(NSTemporaryDirectory())
    }
    
    private static let resumeInfoTempFileName = "NSURLSessionResumeInfoTempFileName"
    private static let resumeInfoLocalPath = "NSURLSessionResumeInfoLocalPath"
    private static func tc_resumeInfoTempFileName(for data: Data) -> String? {
        do {
            guard let dic: [String: String] = (try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]) else {
                return nil
            }
            var fileName = dic[URLSessionTask.resumeInfoTempFileName]
            if nil == fileName {
                fileName = NSString(string: dic[URLSessionTask.resumeInfoLocalPath] ?? "").lastPathComponent
            }
            if nil != fileName {
                fileName = NSString(string: NSTemporaryDirectory()).appendingPathComponent(fileName!)
            }
            return fileName
        } catch {
            return nil
        }
    }
    
    private var tc_resumeCachePath: String? {
        guard let resumeCacheDirectory = self.tc_resumeIdentifier else {
            return nil
        }
        guard let resumeIdentifier = self.tc_resumeIdentifier else {
            return nil
        }
        return type(of: self).tc_resumeCachePath(withDirectory: resumeCacheDirectory, identifier: resumeIdentifier)
    }
    
    private static func tc_resumeData(withIdentifier identifier: String, inDirectory subpath: String) -> Data? {
        guard let data = try? Data.init(contentsOf: URL.init(fileURLWithPath: self.tc_resumeCachePath(withDirectory: subpath, identifier: identifier)), options: [Data.ReadingOptions.uncached, Data.ReadingOptions.alwaysMapped]) else {
            return nil
        }
        guard let tmpDownloadFile: String = self.tc_resumeInfoTempFileName(for: data) else {
            return data
        }
        if self.tc_isTmpResumeCache(resumeDirectory: subpath) {
            return data
        }
        try? FileManager.default.removeItem(atPath: tmpDownloadFile)
        let path = NSString(string: subpath).appendingPathComponent(NSString(string: tmpDownloadFile).lastPathComponent)
        try? FileManager.default.copyItem(atPath: path, toPath: tmpDownloadFile)
        if FileManager.default.fileExists(atPath: tmpDownloadFile) {
            return data
        }
        try? FileManager.default.removeItem(atPath: path)
        return nil
    }
    
    private static func  tc_purgeResumeData(withIdentifier identifier: String, inDirectory subpath: String) {
        let path = self.tc_resumeCachePath(withDirectory: subpath, identifier: identifier)
        if !FileManager.default.fileExists(atPath: path) {
            return
        }
        
        // rm tmp files
        
        guard let data = try? Data.init(contentsOf: URL.init(fileURLWithPath: path), options: [Data.ReadingOptions.uncached, Data.ReadingOptions.alwaysMapped]) else {
            return
        }
        if let tmpDownloadFile = self.tc_resumeInfoTempFileName(for: data) {
            try? FileManager.default.removeItem(atPath: tmpDownloadFile)
            try? FileManager.default.removeItem(atPath: NSString(string: subpath).appendingPathComponent(NSString(string: tmpDownloadFile).lastPathComponent))
        }
        try? FileManager.default.removeItem(atPath: path)
        
    }
    
    func tc_purgeResumeData() {
        guard let resumeIdentifier = self.tc_resumeIdentifier,
            let resumeCacheDirectory = self.tc_resumeCacheDirectory else {
                return
        }
        URLSessionTask.tc_purgeResumeData(withIdentifier: resumeIdentifier, inDirectory: resumeCacheDirectory)
    }
}
