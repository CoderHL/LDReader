//
//  TitleView.h
//  LDReader
//
//  Created by 刘洪 on 2017/10/16.
//  Copyright © 2017年 刘洪. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LDConfiguration.h"

@interface LDTitleView : UILabel

- (id)initWithTitle:(NSString *)title configuration:(LDConfiguration *)configuration;

@property (nonatomic, strong) NSString *title;

@end
