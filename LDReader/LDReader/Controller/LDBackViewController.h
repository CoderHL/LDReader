//
//  LDBackViewController.h
//  LDReader
//
//  Created by mengminduan on 2017/10/16.
//  Copyright © 2017年 mengminduan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LDPageViewController.h"

@interface LDBackViewController : UIViewController
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, assign) NSInteger chapterBelong;

- (void)grabViewController:(LDPageViewController *)viewController;
@end
