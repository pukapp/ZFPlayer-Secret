//
//  VideoDownQueue.m
//  AVPlayerController
//
//  Created by hailong9 on 17/1/2.
//  Copyright © 2017年 hailong9. All rights reserved.
//

#import "TVideoDownQueue.h"
#import "TVideoDownOperation.h"
#import <libkern/OSAtomic.h>
@interface TVideoDownQueue()
@property (nonatomic,weak) TVideoDownOperation* currentDownLoadOperation;
@property (nonatomic,copy) NSDictionary* httpHeader;
@property (nonatomic,strong) TVideoFileManager* fileManager;
@end
@implementation TVideoDownQueue
{
    NSOperationQueue* _downQueue;
//    TVideoFileManager* _fileManager;
    NSURL* _requestUrl;
}

- (instancetype)initWithFileManager:(TVideoFileManager *)fileManager WithLoadingRequest:(AVAssetResourceLoadingRequest *)resource loadingUrl:(NSURL*)url withHttpHead:(NSDictionary *)httpHead
{
    self = [super init];
    _downQueue = [[NSOperationQueue alloc]init];
    _downQueue.maxConcurrentOperationCount = 1;
    self.fileManager = fileManager;
    _requestUrl = url;
    self.assetResource = resource;
     self.httpHeader = httpHead;
    [self addReuqestOperation];
    return self;
}

- (void)reloadAssetResource:(AVAssetResourceLoadingRequest*)request
{
    NSAssert(request.dataRequest.requestedOffset == 0, @"reloadAssetResource error");
    NSUInteger offset = [self.currentDownLoadOperation requestOffset];
    NSUInteger length = [self.currentDownLoadOperation cacheLength];
    self.assetResource = request;
    NSData* temp = [self.fileManager readTempFileDataWithOffset:offset length:length];
    [self.assetResource.dataRequest respondWithData:temp];
}

- (void)addReuqestOperation
{
    NSInteger requestLength = 0;
    if ([self.assetResource respondsToSelector:@selector(requestsAllDataToEndOfResource)] && self.assetResource.dataRequest.requestsAllDataToEndOfResource == YES) {
        requestLength = [self.fileManager getFileLength] - 1;
    }else{
       requestLength = self.assetResource.dataRequest.requestedLength-self.assetResource.dataRequest.currentOffset+self.assetResource.dataRequest.requestedOffset;
    }
    
    NSArray* segmentArr = [self.fileManager getSegmentsFromFile: NSMakeRange(self.assetResource.dataRequest.currentOffset,requestLength) ];
//    NSLog(@"read segmentArr %@   current offset %ld-%ld",segmentArr,self.assetResource.dataRequest.currentOffset,self.assetResource.dataRequest.requestedOffset+self.assetResource.dataRequest.requestedLength-1);
    
//     __weak TVideoFileManager* wFileManager = _fileManager;
     __weak typeof (self) wself = self;
    for (NSArray* element  in segmentArr) {
        
        NSNumber* start = element[0];
        NSNumber* end = element[1];
        BOOL isSave = [element[2] boolValue];
        if (isSave) {
            
            [_downQueue addOperationWithBlock:^{
            
                if(wself.assetResource.isFinished == true || wself.assetResource.isCancelled == true){
                      [wself cancelDownLoad];
                     return ;
                }
                NSUInteger startInteger = start.unsignedIntegerValue;
                NSUInteger totalLength = end.unsignedIntegerValue - startInteger + 1;
                NSData* data = nil;
                
                int bufSize = 1024000;
                while (totalLength > bufSize) {
                    if (wself.assetResource.isCancelled || wself.assetResource.isFinished) {
                       [wself cancelDownLoad];
                        return;
                    }
                    data =  [wself.fileManager readTempFileDataWithOffset:startInteger length:bufSize];
                    [wself.assetResource.dataRequest respondWithData:data];
                    [NSThread sleepForTimeInterval:0.1];
                     startInteger = startInteger + bufSize;
                    totalLength = totalLength - bufSize;
                }
                data =  [wself.fileManager readTempFileDataWithOffset:startInteger length:totalLength];
                [wself.assetResource.dataRequest respondWithData:data];
                if ([wself getCurrentOperaton] == 1) {
                         [wself.assetResource finishLoading];
                }
                
            }];
        }
        else
        {
            TVideoDownOperation* requestOperation = [[TVideoDownOperation alloc]initWithUrl:_requestUrl withRange:NSMakeRange(start.unsignedIntegerValue, end.unsignedIntegerValue - start.unsignedIntegerValue + 1)];
            __weak TVideoDownOperation* wRequestOperation = requestOperation;
            [requestOperation setOperationStartBk:^(NSMutableURLRequest *request) {
                request.allHTTPHeaderFields = wself.httpHeader;
                 wself.currentDownLoadOperation = wRequestOperation;
            }];
            
           
            [requestOperation setDownRespondBk:^(NSUInteger length, NSString *meidaType) {
                    wself.isNetworkError = NO;
                     if (wself.assetResource.contentInformationRequest) {
                         wself.assetResource.contentInformationRequest.contentLength = length;
                         [wself.fileManager setFileLength:length];
                         [wself.assetResource finishLoading];
                     }
            }];
            
            [requestOperation setDownProcessBk:^(NSUInteger offset, NSData *data) {

                [wself.fileManager writeFileData:offset data:data];
                if(wself.assetResource.isFinished != true && wself.assetResource.isCancelled != true )
                {
                      [wself.assetResource.dataRequest respondWithData:data];
                }
                else
                {
                    if (wself.assetResource.dataRequest.requestedLength != 2) {
                        [wself cancelDownLoad];
                    }
                }
            }];
            
            [requestOperation setDownCompleteBk:^(NSError *error, NSUInteger offset, NSUInteger length) {

                 [wself.fileManager saveSegmentData:offset length:length];
                if (error == nil  && wself.assetResource.isFinished != true && wself.assetResource.isCancelled != true && [wself getCurrentOperaton] == 1) {
                    [wself.assetResource finishLoading];
                }
                if (error == nil) {
                    wself.currentDownLoadOperation = nil;
                } else {
                  wself.isNetworkError = YES;
                    if ([wself.delegate respondsToSelector:@selector(loadNetError:)]) {
                        [wself.delegate loadNetError:wself];
                    }
                }
            }];
            [_downQueue addOperation:requestOperation];
        }
    }

}


- (NSUInteger)getCurrentOperaton
{
    return [_downQueue operationCount] ;
}

- (void)cancelDownLoad
{
    @synchronized (self) {
        if (_downQueue) {
            [_downQueue cancelAllOperations];
            _downQueue = nil;
        }
        self.fileManager = nil;
        self.assetResource = nil;
    }
}

- (void)sychronizeProcessToConfigure
{
    if (self.currentDownLoadOperation) {
        NSUInteger offset = [self.currentDownLoadOperation requestOffset];
        NSUInteger length = [self.currentDownLoadOperation cacheLength];
        [self.fileManager saveSegmentData:offset length:length];
    }
}

- (void)dealloc
{
    [self sychronizeProcessToConfigure];
    [self cancelDownLoad];
}
@end
