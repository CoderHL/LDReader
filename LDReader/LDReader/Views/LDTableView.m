//
//  LDTableView.m
//  LDReader
//
//  Created by 刘洪 on 2017/11/8.
//  Copyright © 2017年 刘洪. All rights reserved.
//

#import "LDTableView.h"

@implementation LDTableView


-(instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
    self = [super initWithFrame:frame style:style];
    if (self) {
        [self initialSetting];
    }
    return self;
}

- (void)initialSetting
{
    self.preEndCellIndex = -1;
}

@end
