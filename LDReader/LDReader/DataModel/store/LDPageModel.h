//
//  LDPageModel.h
//  LDReader
//
//  Created by mengminduan on 2017/10/11.
//  Copyright © 2017年 mengminduan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDAttributedString.h"

@interface LDPageModel : NSObject

@property (nonatomic, strong) LDAttributedString *attrString;
@property (nonatomic, strong) NSString *pageString;
@property (nonatomic, assign) NSRange range;
@property (nonatomic, assign) BOOL lastPage;
@property (nonatomic, assign) NSInteger pageIndex;
@property (nonatomic, assign) NSInteger chapterIndex;
@property (nonatomic, strong) NSMutableArray *markArray;
@property (nonatomic, assign) BOOL advertising;
@end
