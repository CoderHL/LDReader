//
//  LDPageViewController.h
//  LDReader
//
//  Created by mengminduan on 2017/10/11.
//  Copyright © 2017年 mengminduan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LDConfiguration.h"

@interface LDPageViewController : UIViewController

@property (nonatomic, assign) NSInteger index;
@property (nonatomic, assign) NSInteger chapterBelong;
@property (nonatomic, strong) UIImageView *backgroundImageView;

+ (void)setBackGround:(BOOL)isImage configuration:(LDConfiguration *)configuration;
@end
