//
//  LDReaderTableViewCell.h
//  LDReader
//
//  Created by 刘洪 on 2017/10/17.
//  Copyright © 2017年 刘洪. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LDAttributedLabel.h"
#import "LDConfiguration.h"
@class LDPageModel;
@interface LDReaderTableViewCell : UITableViewCell

@property (nonatomic, strong) LDAttributedLabel *text_label;

@property (nonatomic, strong) LDPageModel *pageModel;

@property (nonatomic, weak) UIView *tailView;

@property (nonatomic, weak) UIView *advertisingView;

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier andConfiguration:(LDConfiguration *)configuration;

-(void)setPageModel:(LDPageModel *)pageModel config:(LDConfiguration *)configuration;
@end
