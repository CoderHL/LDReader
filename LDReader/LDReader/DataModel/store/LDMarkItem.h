//
//  LDMarkItem.h
//  LDReader
//
//  Created by 刘洪 on 2017/11/6.
//  Copyright © 2017年 刘洪. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LDMarkItem : NSObject

@property (nonatomic, assign) CGPoint startPoint;
@property (nonatomic, assign) CGPoint endPoint;
@property (nonatomic, assign) NSRange range;
@property (nonatomic, assign) BOOL lastLine;

@end
