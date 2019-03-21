//
//  VideoLoadManager.m
//  AVPlayerController
//
//  Created by hailong9 on 16/12/27.
//  Copyright © 2016年 hailong9. All rights reserved.
//

#import "TVideoLoadManager.h"
#import "TVideoDownQueue.h"
#import "TVideoFileManager.h"
#import "TVideoLoader.h"
#import <libkern/OSAtomic.h>
#import "TVideoDownOperation.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <os/lock.h>
@implementation TVideoLoadManager
{
    NSUInteger _fileLength;
    NSUInteger _cancelLength;
    TVideoLoader * _downLoad;
    TVideoFileManager* _fileManager;
    NSMutableArray* _requestArr;
    os_unfair_lock oslock;
    NSData* resourceData;
}


- (instancetype)initWithFileName:(NSString*)fileName
{
    self = [super init];
    _fileManager = [[TVideoFileManager alloc]initWithFileName:fileName];
     _requestArr = [NSMutableArray arrayWithCapacity:0];
    oslock = (OS_UNFAIR_LOCK_INIT);
    return self;
}

+ (NSString*)decodeDownLoadUrl:(NSString*)url
{
    return [NSString stringWithFormat:@"http://%@",url];
}
+ (NSString*)encryptionDownLoadUrl:(NSString *)url
{
    if ([url hasPrefix:@"http"]) {
        return [url substringFromIndex:7];
    }else{
        return url;//[url substringFromIndex:7];
    }
    return nil;
}


- (BOOL)netWorkError
{
    for (TVideoDownQueue* temp in _requestArr) {
        if (temp.isNetworkError == YES) {
            return YES;
        }
    }
    return NO;
}

//#if 1

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
//     NSLog(@"loadingRequest %ld-%ld ", loadingRequest.dataRequest.requestedOffset,loadingRequest.dataRequest.requestedLength+loadingRequest.dataRequest.requestedOffset-1);
    
//    if (_requestArr.count == 1 && loadingRequest.dataRequest.requestedOffset == 0) {
//        TVideoDownQueue* first = _requestArr.firstObject;
//        if (first.assetResource.dataRequest.requestedLength == 2) {
//            [first reloadAssetResource:loadingRequest];
//            return YES;
//        }
//    }
    
    [self checkResourceLoader];
    if (loadingRequest.contentInformationRequest) {
        CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(@"video/mp4"), NULL);
        loadingRequest.contentInformationRequest.contentType = CFBridgingRelease(contentType);
        loadingRequest.contentInformationRequest.byteRangeAccessSupported = YES;
    }
    
    os_unfair_lock_lock(&oslock);
    
    if ([_fileManager getFileLength] != 0 )  {
        
        if (loadingRequest.dataRequest.requestedLength == 2) {
            
            loadingRequest.contentInformationRequest.contentLength = [_fileManager getFileLength];
            NSData* data =  [_fileManager readTempFileDataWithOffset:0 length:2];
            [loadingRequest.dataRequest respondWithData:data];
            [loadingRequest finishLoading];
            os_unfair_lock_unlock(&oslock);
            return true;
        }
    }
    
    NSString* downUrl = [TVideoLoadManager decodeDownLoadUrl:loadingRequest.request.URL.absoluteString];
    TVideoDownQueue* downLoad = [[TVideoDownQueue alloc]initWithFileManager:_fileManager WithLoadingRequest:loadingRequest loadingUrl:[NSURL URLWithString:downUrl]];
    [_requestArr addObject:downLoad];
     os_unfair_lock_unlock(&oslock);
    
    return NO;
 }

//#else
//
//- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
//{
//    NSLog(@"loadingRequest %ld-%ld  toend %d", loadingRequest.dataRequest.requestedOffset,loadingRequest.dataRequest.requestedLength+loadingRequest.dataRequest.requestedOffset-1,loadingRequest.dataRequest.requestsAllDataToEndOfResource);
//
//    [self checkResourceLoader];
//     CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(@"video/mp4"), NULL);
//    loadingRequest.contentInformationRequest.contentType = CFBridgingRelease(contentType);
//    loadingRequest.contentInformationRequest.byteRangeAccessSupported = NO;
//    //exist video cache
//    if ([_fileManager getFileLength] != 0 )  {
//
//        if (loadingRequest.dataRequest.requestedLength == 2) {
//
//            loadingRequest.contentInformationRequest.contentLength = [_fileManager getFileLength];
//            NSData* data =  [_fileManager readTempFileDataWithOffset:0 length:2];
//            [loadingRequest.dataRequest respondWithData:data];
//            [loadingRequest finishLoading];
//
//        }
//        else if(_downLoad &&(loadingRequest.dataRequest.requestedOffset == 0 || loadingRequest.dataRequest.requestedOffset == 2))
//        {
//            _downLoad.assetResource = loadingRequest;
//        }
//        else
//        {
//
//            if (_downLoad) {
//                [_downLoad videoLoaderSychronizeProcessToConfigure];
//                [_downLoad cancel];
//                _downLoad = nil;
//            }
//
//            os_unfair_lock_lock(&oslock);
//            NSString* downUrl = [VideoLoadManager decodeDownLoadUrl:loadingRequest.request.URL.absoluteString];
//            VideoDownQueue* downLoad = [[VideoDownQueue alloc]initWithFileManager:_fileManager WithLoadingRequest:loadingRequest loadingUrl:[NSURL URLWithString:downUrl]];
//            [_requestArr addObject:downLoad];
//            os_unfair_lock_unlock (&oslock);
//
//        }
//         return true;
//    }
//
//    if (loadingRequest.dataRequest.requestedOffset == 0 || loadingRequest.dataRequest.requestedOffset == 2) {
//
//            NSString* downUrl = [VideoLoadManager decodeDownLoadUrl:loadingRequest.request.URL.absoluteString];
//            _downLoad = [[VideoLoader alloc]initWithUrl:[NSURL URLWithString:downUrl] withRange:NSMakeRange(loadingRequest.dataRequest.requestedOffset, loadingRequest.dataRequest.requestedLength)];
//            _downLoad.assetResource = loadingRequest;
//            _downLoad.fileManager = _fileManager;
//            [_downLoad start];
//        return true;
//    }
//
//    return true;
//}
//
//#endif

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
//    NSLog(@"didCancelLoadingRequest  %ld-%ld",loadingRequest.dataRequest.requestedOffset,loadingRequest.dataRequest.requestedOffset+loadingRequest.dataRequest.requestedLength-1);
    os_unfair_lock_lock(&oslock);
        NSMutableArray* removeAr = [NSMutableArray arrayWithCapacity:0];
        for (TVideoDownQueue* temp in _requestArr) {
            AVAssetResourceLoadingRequest * compare = [temp assetResource] ;
            if (compare == loadingRequest || compare.isFinished) {
                [temp cancelDownLoad];
                [removeAr addObject:temp];
            }
        }
        [_requestArr removeObjectsInArray:removeAr];
    os_unfair_lock_unlock(&oslock);
}


- (void)checkResourceLoader
{
    os_unfair_lock_lock(&oslock);
    NSMutableArray* removeAr = [NSMutableArray arrayWithCapacity:0];
    for (TVideoDownQueue* temp in _requestArr) {
        
        AVAssetResourceLoadingRequest * compare = [temp assetResource] ;
        
        [temp cancelDownLoad];
        [temp sychronizeProcessToConfigure];
        if (compare.isCancelled || compare.isFinished) {
            
        } else {
            [compare finishLoadingWithError:nil];
        }        
        [removeAr addObject:temp];
    }
    [_requestArr removeObjectsInArray:removeAr];
    os_unfair_lock_unlock(&oslock);

}

- (void)networkReachable
{
     [[NSNotificationCenter defaultCenter] postNotificationName:@"networkchanged" object:nil];
}

- (void)dealloc
{
}

- (void)videoLoaderComplete:(NSError *)error {
    
}

- (void)videoLoaderProcessOffset:(NSUInteger)offset data:(NSData *)receiveData {
    
}

- (void)videoLoaderRespond:(NSUInteger)length withMediaType:(NSString *)type {
    
}

@end
