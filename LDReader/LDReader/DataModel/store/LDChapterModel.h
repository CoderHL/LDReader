//
//  LDChapterModel.h
//  LDReader
//
//  Created by mengminduan on 2017/10/11.
//  Copyright © 2017年 mengminduan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LDChapterModel : NSObject

@property (nonatomic, strong, nullable) NSString *title;
@property (nonatomic, strong, nullable) NSString *contentString;
@property (nonatomic, strong, nullable) NSString *path;
@property (nonatomic, assign) NSInteger chapterIndex;//从1开始
@property (nonatomic, assign) NSInteger commentCounts;
@end
