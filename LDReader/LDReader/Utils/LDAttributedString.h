//
//  LDAttributedString.h
//  LDReader
//
//  Created by mengminduan on 2017/12/20.
//  Copyright © 2017年 mengminduan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDConfiguration.h"

@interface LDAttributedString : NSObject

- (instancetype)initWithAttributedString:(NSAttributedString *)attrString;

- (NSAttributedString *)convertToAttributedString:(LDConfiguration *)configuration;

- (NSAttributedString *)autoReserveModeColorWithAttributeString:(NSAttributedString *)attributeStr;

@end
