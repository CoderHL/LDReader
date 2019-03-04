//
//  DataParser.m
//  LDReader
//
//  Created by mengminduan on 2017/10/11.
//  Copyright © 2017年 mengminduan. All rights reserved.
//

#import "LDDataParser.h"
#import "DTCoreText.h"
#import "DTCoreTextLayoutFrame+LDExtension.h"

typedef NS_ENUM(NSUInteger, LDAdversingType) {
    LDAdversingTypeTop,
    LDAdversingTypeMiddle,
    LDAdversingTypeBottom,
};
CGFloat advertisingHeight_;
static const NSInteger chapterMaxLenth_ = 10000;
NSString * const LDAdvertising = @"LDAdvertising";//标记广告
NSString * const LDLastAdvertising = @"LDLastAdvertising";
@implementation LDDataParser
{
    NSMutableArray *_cutingPageChapterArray;
    BOOL _stopCutPage;
    LDAdversingType _adversingType;
//    LDConfiguration *_configuration;
    
    
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        _cutingPageChapterArray = [NSMutableArray array];
    }
    return self;
}

- (NSAttributedString *)attrbutedStringFromChapterModel:(LDChapterModel *)chapter configuration:(LDConfiguration *)configuration
{
    @throw [NSException exceptionWithName:@"parse file error" reason:@"no avalible parser for this file" userInfo:nil];
}

- (void)extractChapterWithBookContent:(NSString *)content bookModel:(LDBookModel *)bookModel chapterIndex:(NSInteger)currentChapterIndex complete:(void(^)(NSArray *,BOOL,BOOL))callback
{
    @throw [NSException exceptionWithName:@"parse file error" reason:@"no avalible parser for this file" userInfo:nil];
}

- (LDChapterModel *)changeChapterModelWithPath:(LDChapterModel *)chapter bookModel:(LDBookModel *)bookModel
{
    @throw [NSException exceptionWithName:@"change model error" reason:@"no avalible parser for this file" userInfo:nil];
}

- (void)cutPageWithAttributedString:(NSAttributedString *)attrString configuration:(LDConfiguration *)configuration chapterIndex:(NSInteger)chapterIndex andChapterMarkArray:(NSMutableArray *)chapterMarkArray completeProgress:(void (^)(NSInteger, LDPageModel *, BOOL))callback
{
    if ([_cutingPageChapterArray containsObject:@(chapterIndex)]) {//取消之前为完成的分页任务
        _stopCutPage = YES;
        [_cutingPageChapterArray removeAllObjects];
    }
    [_cutingPageChapterArray addObject:@(chapterIndex)];
    NSMutableArray *subChapterAttrArray = @[].mutableCopy;
    while (attrString.length>chapterMaxLenth_) {
        NSAttributedString *tmpAttrString = [attrString attributedSubstringFromRange:NSMakeRange(0, chapterMaxLenth_)];
        [subChapterAttrArray addObject:tmpAttrString];
        attrString = [attrString attributedSubstringFromRange:NSMakeRange(chapterMaxLenth_, attrString.length-chapterMaxLenth_)];
    }
    NSUInteger subChapterIndex = 0;
    if(subChapterAttrArray && subChapterAttrArray.count)
    {
        if(attrString.length)[subChapterAttrArray addObject:attrString];
        attrString = [(NSAttributedString *)subChapterAttrArray[subChapterIndex] mutableCopy];
    }
    /* bug fix: In rare cases, the bottom line of a page is missing, which causes the content to be discontinued after the page is
     * flipped
     * @reason The total height of the lines calculated when paging is smaller than the total height of the lines of the actual
     * display, resulting in the last line can not be displayed
     * @solution Make sure the total height at the time of pagination does not exceed the total height at the time of the actual
     * display, so we decrease the height of contentFrame by 1
     */
    //    DLog(@"STRINGlENGTH == %zd data == %zd",attrString.length,[attrString.string dataUsingEncoding:encodeMethod]);
    
    CGFloat contentFrameW = configuration.contentFrame.size.width;
    CGFloat contentFrameH = configuration.contentFrame.size.height;
    if (configuration.advertisingIndex>-1) {
        advertisingHeight_ = (contentFrameW)/configuration.aspectRatio;
    }
    CGRect rect = CGRectMake(0, 0, contentFrameW,  contentFrameH- 1);
    DTCoreTextLayouter *layouter = [[DTCoreTextLayouter alloc] initWithAttributedString:attrString];
    layouter.shouldCacheLayoutFrames = YES;
    NSRange pageVisibleRange = NSMakeRange(0, 0);
    NSUInteger rangOffset = 0;
    NSInteger count = 1;        //页数
    NSAttributedString *tmpAttbutedString;
    
    do {
        if (_stopCutPage) {
            _stopCutPage = NO;
            break;
        }
        NSAttributedString *currentPageAttr;
        BOOL advertising = NO;//标记pagemodel的广告
        if (configuration.advertisingIndex>0){//设置了广告
            if (count%(configuration.advertisingIndex) == 0 && count != 1) {//该页设置广告
                advertising = YES;
                _adversingType = arc4random()%3;
                CGRect rect1;
                CGRect rect2;
                [self subareaWithRect1:&rect1 rect2:&rect2 contentFrameW:contentFrameW contentFrameH:contentFrameH];
                NSMutableAttributedString *temp = [[NSMutableAttributedString alloc]initWithAttributedString:[self extractPageWithLayout:layouter rect:rect1 attr:attrString rangeOffset:&rangOffset pageVisibleRange:&pageVisibleRange]];// 广告上端的内容
                [temp addAttribute:LDAdvertising value:@(YES) range:NSMakeRange(0, temp.length)];
                if (rangOffset < attrString.length) {//没到章节最后
                    NSRange subPageVisibleRange = NSMakeRange(0, 0);
                    [temp appendAttributedString:[self extractPageWithLayout:layouter rect:rect2 attr:attrString rangeOffset:&rangOffset pageVisibleRange:&subPageVisibleRange]];//广告下端的内容
                    pageVisibleRange = NSMakeRange(pageVisibleRange.location,  pageVisibleRange.length+subPageVisibleRange.length);
                }else{//章节最后
                    [temp addAttribute:LDLastAdvertising value:@(YES) range:NSMakeRange(temp.length-1, 1)];
                }
                currentPageAttr = temp;
            }else{
                currentPageAttr = [self extractPageWithLayout:layouter rect:rect attr:attrString rangeOffset:&rangOffset pageVisibleRange:&pageVisibleRange];
            }
        }else
        {//没有设置广告
             currentPageAttr = [self extractPageWithLayout:layouter rect:rect attr:attrString rangeOffset:&rangOffset pageVisibleRange:&pageVisibleRange];
        }
        
        LDPageModel *pageModel = [self pageModelWithPageIndex:count -1 pageString:currentPageAttr.string attrString:[[LDAttributedString alloc] initWithAttributedString:currentPageAttr] range:pageVisibleRange chapterIndex:chapterIndex advertising:advertising];
        if (chapterMarkArray && chapterMarkArray.count) {
            pageModel.markArray = [self pageMarkArrayWithChapterMarkArray:chapterMarkArray andPageModel:pageModel];
        }
        
        tmpAttbutedString = [attrString attributedSubstringFromRange:NSMakeRange(rangOffset, attrString.length-rangOffset)];
        if (tmpAttbutedString.length<chapterMaxLenth_/10 && subChapterAttrArray.count){
            subChapterIndex += 1;
            if(subChapterAttrArray.count>subChapterIndex){
                [(NSMutableAttributedString *)attrString appendAttributedString:subChapterAttrArray[subChapterIndex]];
                layouter = [[DTCoreTextLayouter alloc] initWithAttributedString:attrString];
                layouter.shouldCacheLayoutFrames = YES;
            }
        }
        
        BOOL completed = (rangOffset == attrString.length) ? YES : NO;
        if (completed) {
            pageModel.lastPage = YES;
            [_cutingPageChapterArray removeObject:@(chapterIndex)];
        }else{
            pageModel.lastPage = NO;
        }
        callback(count, pageModel, completed);
        count++;
    } while (rangOffset < attrString.length);
}


// 确定广告位置
-(void)subareaWithRect1:(CGRect *)rect1 rect2:(CGRect *)rect2 contentFrameW:(CGFloat)contentFrameW contentFrameH:(CGFloat)contentFrameH
{
    switch (_adversingType) {
        case LDAdversingTypeTop:
        {
            *rect1 = CGRectMake(0, 0, contentFrameW, 100);
            *rect2 = CGRectMake(0, 0, contentFrameW, contentFrameH - 101 - advertisingHeight_);
        }
            break;
        case LDAdversingTypeMiddle:
        {
            *rect1 = CGRectMake(0, 0, contentFrameW, (contentFrameH-advertisingHeight_)/2);
            *rect2 = CGRectMake(0, 0, contentFrameW, contentFrameH-(*rect1).size.height-1-advertisingHeight_);
        }
            break;
        case LDAdversingTypeBottom:
        {
            *rect1 = CGRectMake(0, 0, contentFrameW, contentFrameH - 100 - advertisingHeight_);
            *rect2 = CGRectMake(0, 0, contentFrameW, 100-1);
        }
            break;
        default:
            break;
    }
}


- (NSAttributedString *)extractPageWithLayout:(DTCoreTextLayouter *)layouter rect:(CGRect)rect attr:(NSAttributedString *)attrString rangeOffset:(NSUInteger *)rangOffset pageVisibleRange:(NSRange *)pageVisibleRange
{
    NSUInteger offset = (*rangOffset);
    DTCoreTextLayoutFrame *frame = [layouter layoutFrameWithRect:rect range:NSMakeRange(offset, attrString.length - offset)];
    *pageVisibleRange = [frame visibleStringRange];
    NSRange visibleRange = (*pageVisibleRange);
    *rangOffset = (visibleRange.location + visibleRange.length);
    return [attrString attributedSubstringFromRange:visibleRange];
}


- (LDPageModel *)pageModelWithPageIndex:(NSInteger)pageIndex pageString:(NSString *)pageString attrString:(LDAttributedString *)attrString range:(NSRange)range chapterIndex:(NSInteger)chapterIndex advertising:(BOOL)advertising
{
    LDPageModel *pageModel = [[LDPageModel alloc] init];
    pageModel.pageIndex = pageIndex;
//  pageModel.attrString = [attrString attributedSubstringFromRange:pageVisibleRange];
    pageModel.pageString = pageString;
    pageModel.attrString = attrString;
    pageModel.range = range;
    pageModel.chapterIndex = chapterIndex;
    pageModel.advertising = advertising;
    return pageModel;
}


- (NSMutableArray *)pageMarkArrayWithChapterMarkArray:(NSMutableArray *)chapterMarkArray andPageModel:(LDPageModel *)pageModel
{
    NSMutableArray *tmpArray = [NSMutableArray array];
    [chapterMarkArray enumerateObjectsUsingBlock:^(NSValue * _Nonnull rangeValue, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange chapterMarkRange = rangeValue.rangeValue;
        if (pageModel.range.location <= chapterMarkRange.location && pageModel.range.location+pageModel.range.length >=chapterMarkRange.location + chapterMarkRange.length) {
                [tmpArray addObject:rangeValue];
        }else if(pageModel.range.location <= chapterMarkRange.location &&
                 pageModel.range.location + pageModel.range.length >= chapterMarkRange.location &&
                 pageModel.range.location + pageModel.range.length < chapterMarkRange.location + chapterMarkRange.length){
            NSRange range = NSMakeRange(chapterMarkRange.location, pageModel.range.length + pageModel.range.location - chapterMarkRange.location);
            if (range.length) {
                NSValue *range_Value = [NSValue valueWithRange:range];
                [tmpArray addObject:range_Value];
            }
        }else if (pageModel.range.location > chapterMarkRange.location &&
                  pageModel.range.location < chapterMarkRange.location + chapterMarkRange.length){
            NSRange range = NSMakeRange(pageModel.range.location, chapterMarkRange.location + chapterMarkRange.length - pageModel.range.location);
            if (range.length) {
                NSValue *range_Value = [NSValue valueWithRange:range];
                [tmpArray addObject:range_Value];
            }
        }
        
    }];
    return tmpArray;
}



@end
