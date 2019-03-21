//
//  VideoDownLoader.swift
//  Wire-iOS
//
//  Created by 王杰 on 2019/2/28.
//  Copyright © 2019 Zeta Project Germany GmbH. All rights reserved.
//

import UIKit
import CommonCrypto
//import Alamofire

@objcMembers public class VideoDownLoader: NSObject {
    
    public static let cacheVideoPath: String? = {
        let folders = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory, FileManager.SearchPathDomainMask.userDomainMask, true) as [NSString]
        guard let cachepath = folders.first else {return nil}
        let cachep: NSString = cachepath as NSString
        let path = cachep.appendingPathComponent("video_cache")
        if !FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
        return path
    }()
    
    private static var downloadingUrls: Set = Set<String>()
    
    private static var downedUrls: Set = Set<String>()
    //TODO:
    //MD5 为视频数据加密签名
    @objc(downLoadVideoWithUrl:downloadMd5:)
    public static func downLoadVideo(with downloadUrl: String?, downloadMd5: String? = nil) {
        guard let url = downloadUrl, let md5 = downloadMd5, url.count > 0, md5.count > 0 else {return}
        let exist = cacheFileExists(fileName: url.zf_md5)
        if  exist, let cachefile = cacheFile(fileName: url.zf_md5) {
            let lurl = URL.init(fileURLWithPath: cachefile)
            let data = try? Data.init(contentsOf: lurl)
            guard let d = data, d.zf_MD5Hash().lowercased() == md5 else {return}
            downedUrls.insert(url.zf_md5)
            return
        }
        guard !downedUrls.contains(url.zf_md5) else {return}
        guard !downloadingUrls.contains(url.zf_md5) else {return}
        downloadingUrls.insert(url.zf_md5)
        clearFile(fileName: url.zf_md5)

//        NetworkManager.manager.download(url) { (_, _) -> (destinationURL: URL, options: DownloadRequest.DownloadOptions) in
//            return (URL.init(fileURLWithPath: cacheFile(fileName: url.zf_md5)!), Alamofire.DownloadRequest.DownloadOptions.removePreviousFile)
//            }.responseJSON { (_) in
//                let index = downloadingUrls.firstIndex(of: url.zf_md5)
//                if let ind = index {
//                    downloadingUrls.remove(at: ind)
//                }
//        }
    }

    public static func cacheFileExists(fileName: String?) -> Bool {
        let videoPath = cacheFile(fileName: fileName?.zf_md5)
        guard let videop = videoPath else {return false}
        if !FileManager.default.fileExists(atPath: videop) {
            return false
        }
        return true
    }
    
    public static func cacheFile(fileName: String?) -> String? {
        guard let cache = cacheVideoPath, let file = fileName else {return nil}
        return cache + "/" + file + ".mp4"
    }
    
    private static func clearFile(fileName: String?) {
        guard let cachePath = cacheFile(fileName: fileName) else {return}
        guard FileManager.default.fileExists(atPath: cachePath) else {return}
        try? FileManager.default.removeItem(atPath: cachePath)
    }
}


extension Data {
    func zf_MD5Hash() -> String {
        let digestLen = Int(CC_MD5_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLen)
        let _ = withUnsafeBytes { bytes in
            CC_MD5(bytes, CC_LONG(self.count), result)
        }
        
        let hash = NSMutableString()
        for i in 0..<digestLen {
            hash.appendFormat("%02x", result[i])
        }
        
        result.deallocate()
        
        return String(format: hash as String)
    }
}

extension NSData {
    @objc func zf_MD5Hash() -> String {
        return (self as Data).zf_MD5Hash().lowercased()
    }
}

extension String {
    var zf_md5: String {
        let md5Length = Int(CC_MD5_DIGEST_LENGTH)
        var result: [CUnsignedChar] = Array(repeating: 0, count: md5Length)
        let data = cString(using: .utf8)!
        CC_MD5(data, CC_LONG(data.count-1), &result)
        return (0..<md5Length).reduce("") { $0 + String(format: "%02hhx", result[$1])}
    }
}
