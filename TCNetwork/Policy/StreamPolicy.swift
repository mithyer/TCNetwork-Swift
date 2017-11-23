//
//  StreamPolicy.swift
//  TCNetwork
//
//  Created by ray on 2017/11/21.
//  Copyright © 2017年 ray. All rights reserved.
//

import Alamofire

class StreamPolicy {
    required init() {}
    weak var request: (RequestProtocol & RequestAgentDelegate)? {
        didSet(newRequest) {
            self.downloadIdentifier = newRequest?.apiUrl?.md5_16
        }
    }
    var progress: Progress?
    
    // MARK: Upload
    var constructingBodyClosure: ((_ mutidata: Alamofire.MultipartFormData) -> ())?
    
    // MARK: Download
    var shouldResumeDownload: Bool = false
    var downloadIdentifier: String?
    lazy var downloadResumeCacheDirectory: String? =  {
        var dir: String? = NSTemporaryDirectory() + "TCHTTPRequestResumeCache"
        do {
            try FileManager.default.createDirectory(atPath: dir!, withIntermediateDirectories: true)
        } catch {
            dir = nil
        }
        
        return dir
    }()
    var downloadDestinationPath: String?
    
    func purgeResumeData() {
        self.request?.requestTask?.tc_purgeResumeData()
    }
}
