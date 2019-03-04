//
//  LDReaderTableViewCell.m
//  LDReader
//
//  Created by 刘洪 on 2017/10/17.
//  Copyright © 2017年 刘洪. All rights reserved.
//

#import "LDReaderTableViewCell.h"
#import "LDPageModel.h"

@implementation LDReaderTableViewCell

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    @throw [NSException exceptionWithName:@"LDReaderTableViewCellError" reason:@"Please call '-initWithStyle:reuseIdentifier:andConfiguration:' to init" userInfo:nil];
}

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier andConfiguration:(LDConfiguration *)configuration
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.text_label = [[LDAttributedLabel alloc]initWithFrame:self.bounds andConfiguration:configuration];
        [self.contentView addSubview:self.text_label];
        self.text_label.backgroundColor = [UIColor clearColor];
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    self.text_label.frame = self.bounds;
    
}

-(void)setPageModel:(LDPageModel *)pageModel config:(LDConfiguration *)configuration
{
    _pageModel = pageModel;
    NSAttributedString *tmpAttr = [pageModel.attrString convertToAttributedString:configuration];
    NSAttributedString *newAttr = [pageModel.attrString autoReserveModeColorWithAttributeString:tmpAttr];
    _text_label.attributedString = newAttr ? newAttr : tmpAttr;
    _text_label.rangeInChapter = pageModel.range;
    _text_label.markList = pageModel.markArray;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
}

@end
