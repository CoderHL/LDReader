//
//  TitleView.m
//  LDReader
//
//  Created by 刘洪 on 2017/10/16.
//  Copyright © 2017年 刘洪. All rights reserved.
//

#import "LDTitleView.h"
#import "LDConvertor.h"

@interface LDTitleView ()
{
  LDConfiguration *_configuration;
}

@property (nonatomic, strong) NSDictionary *dict;

@end

@implementation LDTitleView

- (id)initWithTitle:(NSString *)title configuration:(LDConfiguration *)configuration
{
    title = title ? title :@"";
    _configuration = configuration;
    CGRect frame = CGRectMake(configuration.contentFrame.origin.x, 10 + KSafeAreaTopHeight(), configuration.contentFrame.size.width, 20);
    if (self = [super initWithFrame:frame]) {
        [self initializeSettingWithTitle:title configuration:configuration];
    }
    
    return self;
}


-(void)initializeSettingWithTitle:(NSString *)title configuration:(LDConfiguration *)configuration
{
    self.backgroundColor = [UIColor clearColor];
    NSDictionary *attrs = @{
                            NSFontAttributeName:[UIFont systemFontOfSize:12],
                            NSForegroundColorAttributeName:configuration.themeColor
                            };
    self.dict = attrs;
    [self setAttributeTextWithText:title];
}

-(void)setTitle:(NSString *)title
{
    _title = title;
    if (!title) return;
    [self setAttributeTextWithText:title];
}

-(void)setAttributeTextWithText:(NSString *)title
{
    if (!_configuration.isSimple) {
       title = [[LDConvertor getInstance] s2t:title];
    }
    NSAttributedString *attrString = [[NSAttributedString alloc]initWithString:title attributes:self.dict];
    [self setAttributedText:attrString];
}

@end
