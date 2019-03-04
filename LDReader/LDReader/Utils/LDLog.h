//
//  LDLog.h
//  LDPlayer
//
//  Created by mengminduan on 2017/9/4.
//  Copyright © 2017年 mengminduan. All rights reserved.
//

#import <Foundation/Foundation.h>

#define DLog(format,...) CustomLog(format,##__VA_ARGS__)
#define DFLog(level,format,...) CustomFLog(level,format,##__VA_ARGS__)


void CustomLog(NSString *format, ...);
void CustomFLog(int level, NSString *format, ...);
