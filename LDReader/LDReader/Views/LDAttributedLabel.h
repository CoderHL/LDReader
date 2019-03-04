//
//  LDAttributedLabel.h
//  LDReader
//
//  Created by 刘洪 on 2017/11/2.
//  Copyright © 2017年 刘洪. All rights reserved.
//

#import "DTCoreText.h"
@class LDConfiguration;
@interface LDAttributedLabel : DTAttributedLabel

@property (nonatomic, strong) NSMutableArray *markList;

@property (nonatomic, assign) NSRange rangeInChapter;

@property (nonatomic, strong) NSArray<NSString *> *menuTitles;

@property (nonatomic, strong) void (^menuItemClockClick)(NSString *title, NSString *contentStr,NSRange range);

@property (nonatomic, strong) void (^canNotShowMenuBlock)(void);

@property (nonatomic, weak) UIView *readerView;

@property (nonatomic, assign) NSInteger selectedParagraphIndex;
- (instancetype)initWithFrame:(CGRect)frame andConfiguration:(LDConfiguration *)configuration;
@end
