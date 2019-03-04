//
//  LDConfiguration.m
//  LDReader
//
//  Created by 刘洪 on 2017/10/16.
//  Copyright © 2017年 刘洪. All rights reserved.
//

#import "LDConfiguration.h"

@interface LDConfiguration ()
{
    BOOL _isInited; //记录第一次创建;
}
@property (nonatomic, assign) CGRect contentFrame;
@property (nonatomic, strong) UIFont *font;
//@property (nonatomic, strong) UIColor *textColor;
//@property (nonatomic, strong) UIColor *themeColor;
@end

@implementation LDConfiguration
   
#pragma mark -customMethod
//static LDConfiguration *_shareConfiguration;
- (instancetype)init
{
    self = [super init];
    if (self) {
            [self defaultConfiguration];
        }
    return self;
}


+(instancetype)shareConfiguration{

//    static dispatch_once_t onceToken;
//
//    dispatch_once(&onceToken, ^{
        return [[super allocWithZone:NULL] init];
//    });
    
//    if(_shareConfiguration -> _isInited){
//        _unifiedSetting = YES;
//    }
//    _shareConfiguration -> _isInited = YES;
    
}
//+(instancetype)allocWithZone:(struct _NSZone *)zone
//{
//
//    return [self shareConfiguration];
//}
//
//
//-(id) copyWithZone:(struct _NSZone *)zone
//{
//    return [LDConfiguration shareConfiguration];
//}



/**
 默认设置
 */
-(void)defaultConfiguration
{
    self.contentFrame = CGRectMake(20, 30 + KSafeAreaTopHeight(), KScreenWidth - 40, KScreenHeight - 60 - KSafeAreaTopHeight() - KSafeAreaBottomHeight());
    self.settingFrame = CGRectMake(KScreenWidth/3, KScreenHeight/3, KScreenWidth/3, KScreenHeight/3);
    NSValue *p1 = [NSValue valueWithCGRect:CGRectMake(0, 0, KScreenWidth * 1/3, KScreenHeight)];
    NSValue *p2 = [NSValue valueWithCGRect:CGRectMake(KScreenWidth * 1/3, 0, KScreenWidth * 1/3, KScreenHeight * 1/3)];
    self.prePageFrames = @[p1,p2];
    
    NSValue *n1 = [NSValue valueWithCGRect:CGRectMake(KScreenWidth * 2/3, 0, KScreenWidth * 2/3, KScreenHeight)];
    NSValue *n2 = [NSValue valueWithCGRect:CGRectMake(KScreenWidth * 1/3, KScreenHeight * 2/3, KScreenWidth * 1/3, KScreenHeight * 1/3)];
    self.nextPageFrames = @[n1,n2];
    
    self.scrollType = LDReaderScrollPagingVertical;
    self.themeColor = [UIColor grayColor];
    self.textColor = [UIColor blackColor];
    self.fontSize = 12.0;
    self.font = [UIFont systemFontOfSize:self.fontSize];
    self.fontName = self.font.fontName;
    self.lineSpacing = 10;
    self.backgroundColor = [UIColor whiteColor];
//    self.chapterTitleFont = [UIFont boldSystemFontOfSize:19];
    self.chapterTitleAlignment = NSTextAlignmentCenter;
    self.commentEntryEnable = NO;
    self.hasCover = YES;
    self.isSimple = YES;
    self.autoSelectedParagraphColor = [UIColor colorWithRed:.5 green:.5 blue:.5 alpha:.5];
    self.maxCacheSize = 60*1024*1024;
    self.advertisingIndex = -1;
    self.aspectRatio = 2.0;
}


- (nonnull id)copyWithZone:(nullable NSZone *)zone { 
    LDConfiguration *configuration = [[LDConfiguration alloc]init];
    configuration.contentFrame = self.contentFrame;
    configuration.settingFrame = self.settingFrame;
    configuration.prePageFrames = self.prePageFrames;
    configuration.nextPageFrames = self.nextPageFrames;
    configuration.scrollType = self.scrollType;
    configuration.themeColor = self.themeColor;
    configuration.textColor = self.textColor;
    configuration.fontSize = self.fontSize;
    configuration.font = self.font;
    configuration.fontName = self.fontName;
    configuration.lineSpacing = self.lineSpacing;
    
    configuration.backgroundColor = self.backgroundColor;
//    configuration.chapterTitleFont = self.chapterTitleFont;
    configuration.chapterTitleAlignment = self.chapterTitleAlignment;
    configuration.commentEntryEnable = self.commentEntryEnable;
    configuration.hasCover = self.hasCover;
    configuration.isSimple = self.isSimple;
    configuration.autoSelectedParagraphColor = self.autoSelectedParagraphColor;
    configuration.maxCacheSize = self.maxCacheSize;
    configuration.advertisingIndex = self.advertisingIndex;
    configuration.aspectRatio = self.aspectRatio;
    return configuration;
}

@end
