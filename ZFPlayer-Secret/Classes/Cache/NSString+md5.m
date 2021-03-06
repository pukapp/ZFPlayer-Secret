//
//  NSString+md5.m
//  Wire-iOS
//
//  Created by 王杰 on 2018/8/18.
//  Copyright © 2018年 Zeta Project Germany GmbH. All rights reserved.
//

#import "NSString+md5.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (md5)
    
- (NSString*)md5 {
    const char* string = [self UTF8String];
    unsigned char result[16];
    CC_MD5(string, (uint)strlen(string), result);
    NSString* hash = [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
                      result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7],
                      result[8], result[9], result[10], result[11], result[12], result[13], result[14], result[15]];
    
    return [hash lowercaseString];
}
@end
