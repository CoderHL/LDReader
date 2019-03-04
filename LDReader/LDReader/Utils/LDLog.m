//
//  LDLog.m
//  LDPlayer
//
//  Created by mengminduan on 2017/9/4.
//  Copyright © 2017年 mengminduan. All rights reserved.
//

#import "LDLog.h"

void CustomLog(NSString *format, ...)
{
    BOOL logEnable = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"LDLogEnable"] boolValue];
    if (logEnable) {
        va_list args;
        va_start(args, format);
        NSString *string = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);

        NSString *strFormat = [NSString stringWithFormat:@"LDLog<I> | %@",string];
        NSLog(@"%@", strFormat);
    }
}

void CustomFLog(int level, NSString *format, ...)
{
    BOOL logEnable = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"LDLogEnable"] boolValue];
    if (logEnable) {
        va_list args;
        va_start(args, format);
        NSString *string = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        
        NSString *strFormat;
        switch (level) {
            case 1:
                strFormat = [NSString stringWithFormat:@"LDLog<I> | %@",string];
                break;
            case 2:
                strFormat = [NSString stringWithFormat:@"LDLog<W> | %@",string];
                break;
            case 3:
                strFormat = [NSString stringWithFormat:@"LDLog<E> | %@",string];
                break;
            default:
                strFormat = [NSString stringWithFormat:@"LDLog<I> | %@",string];
                break;
        }
        NSLog(@"%@", strFormat);
    }
}
