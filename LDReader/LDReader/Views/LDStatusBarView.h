//
//  StatusBarView.h
//  LDReader
//
//  Created by 刘洪 on 2017/10/16.
//  Copyright © 2017年 刘洪. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LDConfiguration.h"

typedef void(^LDClickBlock)(void);

@interface LDStatusBarView : UIView

- (id)initWithPageCounts:(NSInteger)pageCounts pageIndex:(NSInteger)currentPageIndex commentTitle:(NSString *)title configuration:(LDConfiguration *)configuration;

@property (nonatomic, assign) NSInteger pageCounts;

@property (nonatomic, assign) NSInteger currentPageIndex;

@property (nonatomic, strong) NSString *commentTitle;

@property (nonatomic, strong) LDClickBlock clickBlock;

@end
