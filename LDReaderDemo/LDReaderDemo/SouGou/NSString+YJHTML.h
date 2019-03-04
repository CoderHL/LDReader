//
//  NSString+YJHTML.h
//  LDReaderDemo
//
//  Created by 刘洪 on 2018/12/3.
//  Copyright © 2018年 刘洪. All rights reserved.
//

#import <Foundation/Foundation.h>

// Dependant upon YJNSString+HTML

@interface NSString (YJHTML)

// Instance Methods
- (NSString *)stringByConvertingHTMLToPlainText;
- (NSString *)stringByDecodingHTMLEntities;
- (NSString *)stringByEncodingHTMLEntities;
- (NSString *)stringWithNewLinesAsBRs;
- (NSString *)stringByRemovingNewLinesAndWhitespace;
- (NSString *)deleteStyle;

// DEPRECIATED - Please use NSString stringByConvertingHTMLToPlainText
- (NSString *)stringByStrippingTags; 

@end
