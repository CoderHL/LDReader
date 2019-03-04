//
//  StatusBarView.m
//  LDReader
//
//  Created by 刘洪 on 2017/10/16.
//  Copyright © 2017年 刘洪. All rights reserved.
//

#import "LDStatusBarView.h"
#import "LDConvertor.h"


@interface LDStatusBarView ()
{
    UIView *_containView;
    UIView *_rightView;
    UILabel *_timeLabel;
    UILabel *_pageLabel;
    UIButton *_chapterCommentBtn;
    LDConfiguration *_configuration;
}

@property (nonatomic, weak) UIView *batteryView;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@implementation LDStatusBarView

    static NSInteger const batteryLen = 18;
    static NSInteger const batteryH = 10;
- (id)initWithPageCounts:(NSInteger)pageCounts pageIndex:(NSInteger)currentPageIndex commentTitle:(NSString *)title configuration:(LDConfiguration *)configuration
{
    NSInteger height = 20;
    CGRect frame = CGRectMake(configuration.contentFrame.origin.x, KScreenHeight-height-10 - KSafeAreaBottomHeight(), configuration.contentFrame.size.width, height);
    _configuration = configuration;
    if (self = [super initWithFrame:frame]) {
        //电池
        _containView = [[UIView alloc]init];
        _containView.layer.borderWidth = 1;
        _containView.layer.borderColor = configuration.themeColor.CGColor;
        _containView.backgroundColor = [UIColor clearColor];
        
        
        
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        double deviceLevel = [UIDevice currentDevice].batteryLevel;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangBatteryState:) name:@"UIDeviceBatteryStateDidChangeNotification" object:nil];
        UIView *batteryView = [[UIView alloc] initWithFrame:CGRectMake(2, 2, batteryLen * ABS(deviceLevel), batteryH - 4)];
        self.batteryView = batteryView;
        batteryView.backgroundColor = configuration.themeColor;
        [_containView addSubview:batteryView];
        
        [self addSubview:_containView];

        _rightView = [[UIView alloc]init];
        _rightView.layer.cornerRadius = 1;
        _rightView.backgroundColor = [UIColor grayColor];
        [self addSubview:_rightView];
        
        //时间
        NSString *timeStr = [self getCurrentTime];
        _timeLabel = [[UILabel alloc]init];
        _timeLabel.text = timeStr;
        _timeLabel.textAlignment = NSTextAlignmentLeft;
        _timeLabel.font = [UIFont systemFontOfSize:11];
        _timeLabel.textColor = configuration.themeColor;
        [self addSubview:_timeLabel];
        
        //页码
        _pageLabel = [[UILabel alloc]init];
        _currentPageIndex = currentPageIndex;
        _pageCounts = pageCounts;
        _pageLabel.font = [UIFont systemFontOfSize:11];
        _pageLabel.textAlignment = NSTextAlignmentRight;
        _pageLabel.textColor = configuration.themeColor;
        [self setPageLabelText];
        [self addSubview:_pageLabel];
        
        //章节评论
        _chapterCommentBtn = [UIButton new];
        _chapterCommentBtn.center = CGPointMake(self.ld_width/2, self.ld_height/2);
        _chapterCommentBtn.bounds = CGRectMake(0, 0, 120, 16);
        [_chapterCommentBtn setTitle:title forState:UIControlStateNormal];
        [_chapterCommentBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        _chapterCommentBtn.titleLabel.font = [UIFont systemFontOfSize:11];
        _chapterCommentBtn.backgroundColor = [UIColor grayColor];
        [_chapterCommentBtn addTarget:self action:@selector(chapterCommentClicked) forControlEvents:UIControlEventTouchUpInside];
        if (configuration.commentEntryEnable) {
            _chapterCommentBtn.hidden = NO;
        }else {
            _chapterCommentBtn.hidden = YES;
        }
        [self addSubview:_chapterCommentBtn];

        
        //初始化设置
        [self setUpTimer];
    }
    
    return self;
}


-(void)layoutSubviews
{
    [super layoutSubviews];
    //电池
    _containView.frame = CGRectMake(0, 5, batteryLen + 4, batteryH);
    _rightView.frame = CGRectMake(CGRectGetMaxX(_containView.frame), CGRectGetMaxY(_containView.frame)-_containView.bounds.size.height/2 -1.5, 2, 3);
    //时间
    _timeLabel.frame = CGRectMake(CGRectGetMaxX(_rightView.frame) + 10, 3, CGRectGetMinX(_chapterCommentBtn.frame)-2-(CGRectGetMaxX(_rightView.frame) + 10), 14);
    //页码
    _pageLabel.frame = CGRectMake(CGRectGetMaxX(_chapterCommentBtn.frame)+2, 3, _configuration.contentFrame.size.width - CGRectGetMaxX(_chapterCommentBtn.frame), 14);
    
}

-(NSDateFormatter *)dateFormatter
{
    if (!_dateFormatter) {
        _dateFormatter = [[NSDateFormatter alloc]init];
        [_dateFormatter setDateFormat:@"HH:mm"];
    }
    return _dateFormatter;
}

#pragma mark -customMethod
-(NSString *)getCurrentTime
{
    NSDate *currentDate = [NSDate date];
    return [self.dateFormatter stringFromDate:currentDate];
    
}

-(void)didChangBatteryState:(NSNotification *)notification
{
    double deviceLevel = [UIDevice currentDevice].batteryLevel;
    self.batteryView.ld_width = batteryLen * ABS(deviceLevel);
    
}

-(void)setUpTimer
{
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateTimer) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    
}

- (void)chapterCommentClicked
{
    if (self.clickBlock) {
        self.clickBlock();
    }
}

-(void)updateTimer
{
    _timeLabel.text = [self getCurrentTime];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.timer invalidate];
}


-(void)setPageLabelText
{
    NSString *pageStr = [NSString stringWithFormat:@"第%zd/%zd页",_currentPageIndex + 1,_pageCounts];
    if (!_configuration.isSimple) {
        pageStr = [[LDConvertor getInstance] s2t:pageStr];
    }
        _pageLabel.text = pageStr;
}

-(void)setCurrentPageIndex:(NSInteger)currentPageIndex
{
    _currentPageIndex = currentPageIndex;
    
    [self setPageLabelText];
}

-(void)setPageCounts:(NSInteger)pageCounts
{
    _pageCounts = pageCounts;
    
    [self setPageLabelText];
    
}

- (void)setCommentTitle:(NSString *)commentTitle
{
    _commentTitle = commentTitle;
    if (_chapterCommentBtn) {
        [_chapterCommentBtn setTitle:commentTitle forState:UIControlStateNormal];
    }
}

@end
