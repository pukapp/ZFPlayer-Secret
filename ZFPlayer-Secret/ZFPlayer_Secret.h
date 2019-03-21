//
//  ZFPlayer_Secret.h
//  ZFPlayer-Secret
//
//  Created by 刘超 on 2019/3/21.
//  Copyright © 2019 Secret. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for ZFPlayer_Secret.
FOUNDATION_EXPORT double ZFPlayer_SecretVersionNumber;

//! Project version string for ZFPlayer_Secret.
FOUNDATION_EXPORT const unsigned char ZFPlayer_SecretVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <ZFPlayer_Secret/PublicHeader.h>

#ifndef zf_weakify
#if DEBUG
#if __has_feature(objc_arc)
#define zf_weakify(object) autoreleasepool{} __weak __typeof__(object) weak##_##object = object;
#else
#define zf_weakify(object) autoreleasepool{} __block __typeof__(object) block##_##object = object;
#endif
#else
#if __has_feature(objc_arc)
#define zf_weakify(object) try{} @finally{} {} __weak __typeof__(object) weak##_##object = object;
#else
#define zf_weakify(object) try{} @finally{} {} __block __typeof__(object) block##_##object = object;
#endif
#endif
#endif

#ifndef zf_strongify
#if DEBUG
#if __has_feature(objc_arc)
#define zf_strongify(object) autoreleasepool{} __typeof__(object) object = weak##_##object;
#else
#define zf_strongify(object) autoreleasepool{} __typeof__(object) object = block##_##object;
#endif
#else
#if __has_feature(objc_arc)
#define zf_strongify(object) try{} @finally{} __typeof__(object) object = weak##_##object;
#else
#define zf_strongify(object) try{} @finally{} __typeof__(object) object = block##_##object;
#endif
#endif
#endif

// Screen width
#define ZFPlayerScreenWidth     [[UIScreen mainScreen] bounds].size.width
// Screen height
#define ZFPlayerScreenHeight    [[UIScreen mainScreen] bounds].size.height


#import "ZFPlayerController.h"
#import "ZFPlayerGestureControl.h"
#import "ZFPlayerMediaPlayback.h"
#import "ZFPlayerMediaControl.h"
#import "ZFOrientationObserver.h"
#import "ZFKVOController.h"
#import "UIScrollView+ZFPlayer.h"
#import "ZFPlayerLogManager.h"
#import "ZFDouYinControlView.h"
#import "ZFSecretPlayerControlView.h"
#import "ZFAVPlayerManager.h"
#import "ZFPlayerNotification.h"
#import "ZFIJKPlayerManager.h"
#import "ZFSmallFloatControlView.h"
#import "UIImageView+ZFCache.h"

#import "UIView+ZFFrame.h"
#import "ZFUtilities.h"
#import "ZFVolumeBrightnessView.h"
#import "ZFNetworkSpeedMonitor.h"
#import "ZFPlayerControlView.h"
#import "KSMediaPlayerManager.h"

#import "NSString+md5.h"
#import "TVideoDownQueue.h"
#import "TVideoFileManager.h"
#import "TVideoLoader.h"
#import "TVideoDownOperation.h"
#import "TVideoLoadManager.h"
