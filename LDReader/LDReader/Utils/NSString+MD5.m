//
//  NSString+MD5.m
//  LDReader
//
//  Created by 刘洪 on 2018/4/13.
//  Copyright © 2018年 刘洪. All rights reserved.
//

#import "NSString+MD5.h"
#import <CommonCrypto/CommonDigest.h>
@implementation NSString (MD5)
- (id)MD5
{
    if (self.length == 0)return nil;
    const char *cStr = [self UTF8String];
    if (!cStr){
        NSStringEncoding stringEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
        cStr = [self cStringUsingEncoding:stringEncoding];
    }
    if (!cStr) cStr = [self cStringUsingEncoding:NSUnicodeStringEncoding];
    unsigned char digest[16];
    CC_MD5( cStr, (CC_LONG)strlen(cStr), digest ); // This is the md5 call
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    
    return  output;
    
}
@end
