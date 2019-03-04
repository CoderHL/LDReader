//
//  LDConfiguration.h
//  LDReader
//
//  Created by 刘洪 on 2017/10/16.
//  Copyright © 2017年 刘洪. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, LDReaderScrollType) {
    LDReaderScrollCurl,                 //横向仿真翻页
    LDReaderScrollPagingHorizontal,     //横向整页滑动
    LDReaderScrollPagingVertical,       //竖向整页滑动
    LDReaderScrollVertical              //竖向连续滑动
};

typedef NS_ENUM(NSUInteger, LDBookype) {
    LDBookText,
    LDBookEpub,
};


@interface LDConfiguration : NSObject
//basic configuration
@property (nonatomic, assign, readonly) CGRect contentFrame;
@property (nonatomic, assign) LDReaderScrollType scrollType;
@property (nonatomic, assign) LDBookype bookType;
@property (nonatomic, assign) CGRect settingFrame;
@property (nonatomic, strong) NSArray *prePageFrames;
@property (nonatomic, strong) NSArray *nextPageFrames;
/*
 * 是否打开章节评论入口，默认为NO。设置YES时阅读器每个页面下方均会出现一个button入口，注意此处入口和章节末尾评论入口不同！
 */
@property (nonatomic, assign) BOOL commentEntryEnable;
//theme
@property (nonatomic, assign) CGFloat lineSpacing;//需要重分页
@property (nonatomic, assign) CGFloat fontSize;//需要重分页
@property (nonatomic, strong) NSString *fontName;//需要重分页
@property (nonatomic, strong) UIImage *backgroundImage;
@property (nonatomic, strong) UIColor *backgroundColor;

@property (nonatomic, strong) UIColor *textColor;// 正文字体颜色，默认黑色,需要重分页
@property (nonatomic, strong) UIColor *themeColor; // 标题及状态栏颜色，默认灰色
//title(标题大小为正文大小的1.5倍,不需要手动设置)
//@property (nonatomic, strong) UIFont *chapterTitleFont;//注意:设置标题字体应该放在正文字体的前面
@property (nonatomic, assign) NSTextAlignment chapterTitleAlignment;

@property (nonatomic, assign) BOOL hasCover;//default YES 是否需要封面

@property (nonatomic, assign) BOOL isSimple; //default YES 文字是否简体 需要重分页

@property (nonatomic, strong) UIColor *autoSelectedParagraphColor;//选中段落的颜色
@property (nonatomic, assign) NSInteger maxCacheSize;//整本书的最大缓存容量,默认60M

//广告间隔(1,2...0代表不存在广告)
@property (nonatomic) NSInteger advertisingIndex;

//宽高比
@property (nonatomic) CGFloat aspectRatio;

+(instancetype)shareConfiguration;

@end
