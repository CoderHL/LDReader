//
//  LDReader.m
//  LDReader
//
//  Created by mengminduan on 2017/10/11.
//  Copyright © 2017年 mengminduan. All rights reserved.
//

#import "LDReader.h"
#import "LDPageModel.h"
#import "LDPageViewController.h"
#import "LDBackViewController.h"
#import "LDDataParser.h"
#import "LDReaderTableViewCell.h"
#import "LDUtil.h"
#import "LDLog.h"
#import "LDAttributedLabel.h"
#import "LDTableView.h"
#import "LDTitleView.h"
#import "LDStatusBarView.h"
#import "DTCoreTextLayoutFrame+LDExtension.h"
#import "UIImage+LDExtension.h"


#define KZoom_Scale_X ((KScreenWidth)/(375.0))
#define KZoom_Scale_Y ((KScreenHeight)/(667.0))
NSString *const LDReaderVersion = @"1.0.2";
@interface LDReader () <UIPageViewControllerDelegate, UIPageViewControllerDataSource, UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate>
{
    NSMutableDictionary *chapterCacheDict;
    NSMutableDictionary *chapterModelCaches;
    BOOL firstIntoReader;
    NSInteger _currentCellIndex;
    BOOL _unifiedSetting;   //阅读过程中进行多个阅读器相关设置
    BOOL _neddUnifiedSetting;   //需要统一设置
    NSString *_unifiedSettingKey;   //统一设置最后的key
    NSString *_unifiedSettingValue;
    BOOL _unifiedSettingWithNoRecute;   //统一设置中不需要进行重分页的设置部分
}

@property (nonatomic, strong) LDDataParser *dataParser;
@property (nonatomic, strong) dispatch_queue_t cacheQueue;
@property (nonatomic, strong) UIPageViewController *pageVC;

@property (nonatomic, weak) LDTableView *tableView;
@property (nonatomic, weak) LDStatusBarView *statusBarView;
@property (nonatomic, weak) LDTitleView *titleView;

//监听的属性
@property (nonatomic, strong) NSArray *observeKeyPaths;
//重新分页
@property (nonatomic, assign) BOOL isReCutChapter;

@property (nonatomic, strong) UIImageView *backgroundImageView;
//当前页索引(内部从0开始)
@property (nonatomic, assign) NSInteger currentPageIndex;
//当前章节的索引(从1开始)
@property (nonatomic, assign) NSInteger currentChapterIndex;
//tableview数据源
@property (nonatomic, strong) NSMutableArray *tableViewDataArray;
//翻页是否由点击手势触发
@property (nonatomic, assign) BOOL pageTurningByTap;
//章节是否执行过缓存
@property (nonatomic, strong) NSMutableDictionary *chapterCacheFlags;
@property (nonatomic, assign) NSInteger startLocationPreviousPage;
//-1向前翻页，1向后翻页，0不翻页
//@property (nonatomic, assign) NSInteger pageTurningByAuto;
@property (nonatomic, assign) BOOL pageHunger;
@property (nonatomic, assign) LDReaderState state;
@property (nonatomic, strong) NSMutableDictionary *lastCommentViewHeightDic;
@property (nonatomic, assign) BOOL fedByWholeBook;
@property (nonatomic, strong) NSMutableDictionary *markBookCacheDic;
@property (nonatomic, strong) NSMutableArray *markChapterArray;//每本书的所有章节的标注(字典数组)
@property (nonatomic, assign) BOOL isJumpChapter;//跳章(区分章节内跳转)

@property (nonatomic, weak) LDAttributedLabel *currentAttributeLabel;

//@property (nonatomic, strong) NSArray *wholeBookChapterTitles;

//统一设置
@property (nonatomic, strong) void (^unifiedSettingBlock)(void);
@end

UIColor *_preTextColor; //设置当前文本颜色
extern CGFloat advertisingHeight_;
extern BOOL _unifiedSetting;   //统一设置阅读器配置
extern NSString *_bookPath;
extern NSArray *wholeBookChapterTitles_;
@implementation LDReader
@synthesize configuration = _configuration;
#pragma mark - 对外接口

//注意:pageIndex参数需要换
- (void)readWithChapter:(LDChapterModel *)chapterModel pageIndex:(NSInteger)pageIndex
{
    DLog(@"readWithChapter");
    if (![self validateReaderData:chapterModel]) {
        return;
    }
    if (firstIntoReader) {
        [self cleanReaderCacheIfNeed];
    }
    //判断是否是跳章操作
    if (_currentChapterIndex != chapterModel.chapterIndex){
        self.isJumpChapter = YES;
    }
    
    if ([self.chapterCacheFlags[@(chapterModel.chapterIndex)] integerValue] == 1 && !_isReCutChapter && !self.manualJumpChapterOrPage) {
        return;
    }
    [self.chapterCacheFlags setObject:@"1" forKey:@(chapterModel.chapterIndex)];
    
    if (![NSThread isMainThread]) {
        [self forwardCacheWithChapterModel:chapterModel];
        return;
    }
    if ((firstIntoReader && !self.fedByWholeBook) || _isReCutChapter) {
        [self postReaderStateNotification:LDReaderBusy];
    }
    __block NSMutableArray *array;
    if(!self.isReCutChapter){
        array = [self pageArrayFromCache:chapterModel.chapterIndex];
        DLog(@"非重分页,有缓存 chapterIndex == %zd",chapterModel.chapterIndex);
    }else{
        [self cleanChapterCache];
        [self.chapterCacheFlags removeAllObjects];
        [self.chapterCacheFlags setObject:@"1" forKey:@(chapterModel.chapterIndex)];
    }
    if (self.fedByWholeBook && self.manualJumpChapterOrPage && (!array || array.count == 0)) {
        chapterModel.path = [NSString stringWithFormat:@"%@/chapter%zd.txt",_bookPath,chapterModel.chapterIndex];
    }
    if (!array || array.count == 0 || self.isReCutChapter) {
        if (self.manualJumpChapterOrPage) {
            [self postReaderStateNotification:LDReaderBusy];
        }
        dispatch_async(self.cacheQueue, ^{
            NSMutableArray *nextPageArray = [self pageArrayFromCache:chapterModel.chapterIndex];
            if (nextPageArray) {
                DLog(@"forward cache finished!");
                array = nextPageArray;
                return;
            }
//            [NSThread sleepForTimeInterval:5];
            array = [NSMutableArray array];
            NSAttributedString *attrString = [self.dataParser attrbutedStringFromChapterModel:chapterModel configuration:self.configuration];
            if (!chapterModel.title || [chapterModel.title isEqualToString:@""]) {
                chapterModel.title = self.bookModel.name;
            }
            [self cacheModelWithIndex:chapterModel.chapterIndex withObject:chapterModel];

//            if(!attrString.length) {
//                dispatch_sync(dispatch_get_main_queue(), ^{
//                    [self postReaderStateNotification:LDReaderReady];
//                });
//                return;
//            }
            NSMutableArray *markChapterArray = [self getChapterMarkArrayWithChapterIndex:chapterModel.chapterIndex isDeleteChapterModelArray:NO];
            [self.dataParser cutPageWithAttributedString:attrString configuration:self.configuration  chapterIndex:chapterModel.chapterIndex andChapterMarkArray:markChapterArray completeProgress:^(NSInteger completedPageCounts, LDPageModel *page, BOOL completed) {
                [array addObject:page];
                if (completed) {
                    [self cacheChapterWithIndex:chapterModel.chapterIndex withObject:array];
                    DLog(@"normal cache finished! chapterIndex == %zd",chapterModel.chapterIndex);
                    dispatch_async(dispatch_get_main_queue(), ^() {
                        [self processWithPageArray:array chapterModel:chapterModel pageIndex:pageIndex];
                    });
                    [self successRequestPageArrayWithChapterModel:chapterModel andPageModel:array.lastObject];
                }
            }];
        });
    }
    
    if (array != nil && self.manualJumpChapterOrPage) {
        [self jumpChapterOrFirstInReaderSettingWithArray:array chapterModel:chapterModel andPageIndex:pageIndex];
    }
}

- (void)readWithFilePath:(NSString *)path andChapterIndex:(NSInteger)chapterIndex pageIndex:(NSInteger)pageIndex
{
    self.fedByWholeBook = YES;
    [self postReaderStateNotification:LDReaderBusy];
    NSError *error;
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    LDDataParserEncodeMethod = NSUTF8StringEncoding;
    [self callBackWithEncodingFailWithContent:content andError:error];
    if (error && content)return;
    if (!content) {
        NSError *error;
         NSStringEncoding stringEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
        content = [NSString stringWithContentsOfFile:path encoding:stringEncoding error:&error];
        LDDataParserEncodeMethod = stringEncoding;
        [self callBackWithEncodingFailWithContent:content andError:error];
        if (error && content)return;
    }
    
    if (!content) {
        NSError *error;
        NSStringEncoding stringEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_2312_80);
        content = [NSString stringWithContentsOfFile:path encoding:stringEncoding error:&error];
        LDDataParserEncodeMethod = stringEncoding;
        [self callBackWithEncodingFailWithContent:content andError:error];
        if (error && content)return;
    }
    if (!content) {
        content = @"";
        [self callBackWithEncodingFailWithContent:content andError:error];
    }
    
    __block NSInteger chapter_Index = chapterIndex;
    __weak typeof(self) weakSelf = self;
    [self.dataParser extractChapterWithBookContent:content bookModel:self.bookModel chapterIndex:chapterIndex complete:^(NSArray *chapters,BOOL completed,BOOL cached) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            if ([weakSelf.delegate respondsToSelector:@selector(reader:chapterTable:)] && completed) {
                [weakSelf.delegate reader:weakSelf chapterTable:chapters];
            }
            if (!completed || cached) {
                if (chapter_Index <= chapters.count){
                    chapter_Index -= 1;
                }else{
                    chapter_Index = 0;
                }
                LDChapterModel *chapterModel = [[LDChapterModel alloc]init];
                NSDictionary *chapterDic = chapters[chapter_Index];
                chapterModel.chapterIndex = [chapterDic[@"index"] integerValue];
                chapterModel.title = chapterDic[@"title"];
                chapterModel.path = [NSString stringWithFormat:@"%@/chapter%zd.txt",_bookPath,chapterModel.chapterIndex];
                [weakSelf readWithChapter:chapterModel pageIndex:pageIndex];
            }
        });
    }];
}

- (void)callBackWithEncodingFailWithContent:(NSString *)content andError:(NSError *)error
{
    if (error && content && [self.delegate respondsToSelector:@selector(reader:failedWithError:)]) {
        [self.delegate reader:self failedWithError:[NSError errorWithDomain:@"ldreader" code:-8002 userInfo:@{NSLocalizedFailureReasonErrorKey:@"文本编码方式错误"}]];
    }
    
}

#pragma mark - customMethod

- (BOOL)validateReaderData:(LDChapterModel *)chapterModel
{
    if (!chapterModel)  return NO;
    if (chapterModel.chapterIndex <= 0) return NO;
    if (!chapterModel.path || ![[NSFileManager defaultManager] fileExistsAtPath:chapterModel.path isDirectory:nil]) {
        if (!chapterModel.contentString)    return NO;
        LDChapterModel *model = [self.dataParser changeChapterModelWithPath:chapterModel bookModel:self.bookModel];
        if (model) {
            chapterModel.path = model.path;
            chapterModel.contentString = nil;
        }
    }
    
    return YES;
}

//回调当前章节所有页面内容
- (void)callBackCurrentChapterPagesWithPageModelArray:(NSArray *)pageModelArray{
    if ([self.delegate respondsToSelector:@selector(reader:currentChapterWithPages:currentChapterIndex:)] && [self pageArrayFromCache:_currentChapterIndex].count) {
        NSMutableArray *pageArray = [NSMutableArray array];
        for (LDPageModel *pageModel in pageModelArray) {
            [pageArray addObject:pageModel.pageString];
        }
        [self.delegate reader:self currentChapterWithPages:pageArray currentChapterIndex:_currentChapterIndex];
    }
}

- (void)processWithPageArray:(NSArray *)array chapterModel:(LDChapterModel *)chapterModel pageIndex:(NSInteger)pageIndex
{
    DLog(@"processWithPageArray == %@ ,pageIndex == %zd",array,pageIndex);
    if ((self.state == LDReaderBusy && !_isReCutChapter) || !self.tableView) {
        [self postReaderStateNotification:LDReaderReady];
    }
    
    if (_isReCutChapter) {
        self.isReCutChapter = NO;
        [self initialTableViewDataWithArray:array];
        NSArray *pageArrayNew = array;
        __block NSInteger newIndex = 0;
        [pageArrayNew enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            LDPageModel *pageM = (LDPageModel *)obj;
            if (self.startLocationPreviousPage >= pageM.range.location && self.startLocationPreviousPage < pageM.range.location + pageM.range.length) {
                newIndex = idx;
                *stop = YES;
            }
        }];
        if (self.tableView) {
            if(newIndex+1 == pageArrayNew.count){
                self.tableView.isLastPage = YES;
                DLog(@"重分页最后一页 %zd",pageArrayNew.count);
                self.tableView.isRequestNextChaper = YES;
            }
            if(newIndex == 0){
                self.tableView.isFirstPage = YES;
                self.tableView.isRequestPreChaper = YES;
            }
//            if (self.tableView.isRequestNextChaper == NO &&
//                self.tableView.isRequestPreChaper == NO) {
                if (self.state == LDReaderBusy) {
                    [self postReaderStateNotification:LDReaderReady];
                }
//            }
            _currentCellIndex = newIndex;
            self.statusBarView.currentPageIndex = newIndex;
        }
        _currentPageIndex = newIndex;
        [self callBackCurrentChapterPagesWithPageModelArray:array];
        if ([self.delegate respondsToSelector:@selector(reader:progressWithChapter:pageCounts:pageIndex:currentWordIndex:)]) {
            LDPageModel *pageMode = array[_currentPageIndex];
            [self.delegate reader:self progressWithChapter:self.currentChapterIndex pageCounts:array.count pageIndex:_currentPageIndex + 1 currentWordIndex:pageMode.range.location];
        }
        [self readPage:newIndex];
        [self forwardCacheIfNeed:NO];
        [self forwardCacheIfNeed:YES];
    }
    
    if(firstIntoReader) {
        if (self.state == LDReaderBusy) {
            [self postReaderStateNotification:LDReaderReady];
        }
        firstIntoReader = NO;
        if(self.lastReadWordIndex){//有历史进度
            NSArray *pageArrayNew = array;
            __block NSInteger newPageIndex = 0;
            [pageArrayNew enumerateObjectsUsingBlock:^(LDPageModel *pageM, NSUInteger idx, BOOL *stop) {
                if (self.lastReadWordIndex >= pageM.range.location && self.lastReadWordIndex < pageM.range.location + pageM.range.length) {
                    newPageIndex = idx+1;
                    *stop = YES;
                }
            }];
            if (newPageIndex == 0) newPageIndex = 1;
            pageIndex = newPageIndex;
        }else{
            pageIndex = pageIndex;
        }
        [self jumpChapterOrFirstInReaderSettingWithArray:array chapterModel:chapterModel andPageIndex:pageIndex];
        if (self.configuration.hasCover) {
            [self loadCoverImage];
        }else{
            [self addGestureRecognizerAndCallback];
        }
    }
    
    if (self.manualJumpChapterOrPage) {
        [self jumpChapterOrFirstInReaderSettingWithArray:array chapterModel:chapterModel andPageIndex:pageIndex];
    }
    
//    if (self.pageTurningByAuto) {
//        DLog(@"auto page turning by normal state...");
//        if (self.pageTurningByAuto == 1) {
//            self.pageTurningByAuto = 0;
//            [self nextPage];
//        }else {
//            self.pageTurningByAuto = 0;
//            [self prePage];
//        }
//    }
    if (self.pageHunger) {
        [self loadPageViewController];
        [self readPage:self.currentPageIndex];
        self.pageHunger = NO;
    }
    
//    if (self.pageVC) {
//        UIScrollView *scroll = [self getScrollViewFromPageVC];
//        if (scroll.tag) {
//            [self loadPageViewController];
//            [self readPage:self.currentPageIndex];
//        }
//    }
}



- (void)jumpChapterOrFirstInReaderSettingWithArray:(NSArray *)array chapterModel:(LDChapterModel *)chapterModel andPageIndex:(NSInteger)pageIndex{
    if(array.count == 1) self.tableView.isRequestNextChaper = YES;
    self.currentChapterIndex = chapterModel.chapterIndex;
    pageIndex = (pageIndex <= 0) ? 0 : (pageIndex - 1);
    // 防止历史进度大于当前总页数
    pageIndex = (pageIndex >= array.count) ? array.count -1 : pageIndex;
    _currentPageIndex = pageIndex;
    if (self.manualJumpChapterOrPage) {
        [self setCurrentCellIndexAndTableViewDatas];
        self.statusBarView.pageCounts = array.count;
        self.statusBarView.currentPageIndex = _currentPageIndex;
    }else{
        [self initialTableViewDataWithArray:array];
        _currentCellIndex = pageIndex;
    }
    if (self.tableView) {
        [self readPage:_currentCellIndex];
    }else{
        [self readPage:_currentPageIndex];
    }
    if ([self.delegate respondsToSelector:@selector(reader:progressWithChapter:pageCounts:pageIndex: currentWordIndex:)]) {
//        NSArray *array = [self pageArrayFromCache:self.currentChapterIndex];
        LDPageModel *pageMode = array[_currentPageIndex];
        [self.delegate reader:self progressWithChapter:self.currentChapterIndex pageCounts:array.count pageIndex:self.currentPageIndex + 1 currentWordIndex:pageMode.range.location];
    }
    if (chapterModel.chapterIndex > 1 && self.tableView) {
        self.tableView.isRequestPreChaper = YES;
        self.tableView.tableViewScrollDirection = LDTableViewScrollDirectionBottom;
    }
    self.manualJumpChapterOrPage = NO;
    self.isJumpChapter = NO;
    [self forwardCacheIfNeed:YES];
    [self forwardCacheIfNeed:NO];
}



- (void)postReaderStateNotification:(LDReaderState)state
{
    self.state = state;
    if (state == LDReaderBusy) {
        self.view.userInteractionEnabled = NO;
    }else {
        if (_unifiedSetting) {
            _unifiedSettingWithNoRecute = YES;
            if (self.unifiedSettingBlock) {
                self.unifiedSettingBlock();
            }
            _unifiedSetting = NO;
            _unifiedSettingWithNoRecute = NO;
        }
        self.view.userInteractionEnabled = YES;
    }
    if ([self.delegate respondsToSelector:@selector(reader:readerStateChanged:)]) {
        [self.delegate reader:self readerStateChanged:state];
    }
}


    

#pragma mark - Table View 逻辑
- (void)initialTableViewDataWithArray:(NSArray *)array
{
    if (self.configuration.scrollType == LDReaderScrollCurl || self.configuration.scrollType == LDReaderScrollPagingHorizontal) {
        return;
    }
    self.statusBarView.pageCounts = array.count;
    [self setChapterTitle];
    [self.tableViewDataArray removeAllObjects];
    [self.tableViewDataArray addObjectsFromArray:array];//添加数据源
}
//reloadIndex:1下一章,-1上一章
-(void)reloadTableViewWithReloadIndex:(NSInteger)reloadIndex
{
    [self getAllTableViewDatasWithReloadIndex:reloadIndex];
    
}

- (CGFloat)addOffsetWithPreChapterIndex:(NSInteger)preChapterIndex
{
    CGFloat addOffsetY = [[self.lastCommentViewHeightDic objectForKey:@(preChapterIndex)] floatValue] - self.tableView.ld_height;
    addOffsetY = addOffsetY>0 ? addOffsetY : 0;
    return addOffsetY;
}


//根据当前章节以及当前页算出tableView的数据源以及cellIndex
-(void)setCurrentCellIndexAndTableViewDatas
{
        [self.tableViewDataArray removeAllObjects];
        if (_currentChapterIndex > 1 ) {
            [self.tableViewDataArray addObjectsFromArray:[self getPreChapterPageArray]];
            [self.tableViewDataArray addObjectsFromArray:[self getCurrentChapterPageArray]];
            [self.tableViewDataArray addObjectsFromArray:[self getNextChapterPageArray]];
        }else if(_currentChapterIndex == 1 ){
            [self.tableViewDataArray addObjectsFromArray:[self getCurrentChapterPageArray]];
            [self.tableViewDataArray addObjectsFromArray:[self getNextChapterPageArray]];
        }
    _currentCellIndex = [[self getPreChapterPageArray] count] + _currentPageIndex;
}

- (void)successRequestPageArrayWithChapterModel:(LDChapterModel *)chapterModel andPageModel:(LDPageModel *)pageModel
{
//    NSLog(@"successRequestPageArrayWithChapterModel chaperIndex == %zd",chapterModel.chapterIndex);
    if (self.pageVC) {
        return;
    }
    [self preCalculationChapterPageWithPageModel:pageModel];
    if (self.tableView.isRequestNextChaper) {
        if (_currentChapterIndex+1 == chapterModel.chapterIndex) {
            dispatch_async(dispatch_get_main_queue(), ^{
                DLog(@"预缓存下一章成功,刷新下一章");
                self.tableView.isRequestNextChaper = NO;
                [self reloadTableViewWithReloadIndex:1];
            });
        }
    }
    if (self.tableView.isRequestPreChaper) {
        if (_currentChapterIndex-1 == chapterModel.chapterIndex) {
            dispatch_async(dispatch_get_main_queue(), ^{
                DLog(@"预缓存上一章成功,刷新上一章");
//                [self postReaderStateNotification:LDReaderReady];
                self.tableView.isRequestPreChaper = NO;
                [self reloadTableViewWithReloadIndex:-1];
            });
        }
    }
}



- (void)updateReaderStateWithIsNext:(BOOL)isNext{

    switch (self.configuration.scrollType) {
        case LDReaderScrollVertical:
        case LDReaderScrollPagingVertical:
        {
            if(self.tableView.contentOffset.y == (self.tableView.contentSize.height - self.tableView.ld_height) && isNext && [_chapterCacheFlags objectForKey:@(self.currentChapterIndex + 1)]){
                [self postReaderStateNotification:LDReaderBusy];
            }else if (self.tableView.contentOffset.y == 0 && !isNext && [_chapterCacheFlags objectForKey:@(self.currentChapterIndex - 1)]){
                [self postReaderStateNotification:LDReaderBusy];
            }
        }
                break;
            default:
                break;
        }
}

- (NSInteger)visibleCellsCount
{
    __block NSInteger visibleCellsCount = 0;
    [self.tableView.visibleCells enumerateObjectsUsingBlock:^(__kindof UITableViewCell * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.hidden == NO) {
            visibleCellsCount++;
        }
    }];
    DLog(@"visibleCellsCount == %zd",visibleCellsCount);
    return visibleCellsCount;
}


#pragma mark - UI 渲染

- (void)viewDidLoad {
    [super viewDidLoad];
    
    chapterCacheDict = [NSMutableDictionary dictionary];
    chapterModelCaches = [NSMutableDictionary dictionary];
    self.chapterCacheFlags = [NSMutableDictionary dictionary];
    [self addObserverForConfiguration];
    [self loadReaderView];
    
    self.view.backgroundColor = self.configuration.backgroundColor;
    
    firstIntoReader = YES;
    _currentChapterIndex = -1;
    self.startLocationPreviousPage = -1;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deleteOldFilesWithCompletionBlock)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deleteOldFilesWithCompletionBlock)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
}

- (void)addTitleViewAndStatusViewTo:(UIView *)target
{
    [self addTitleViewAndStatusViewTo:target atPageIndex:_currentPageIndex atChapterIndex:_currentChapterIndex];
}

- (void)addTitleViewAndStatusViewTo:(UIView *)target atPageIndex:(NSInteger)pageIndex atChapterIndex:(NSInteger)chapterIndex
{
    NSString *title;
    if (!pageIndex) title = self.bookModel.name;
    else title = [[self chapterModelFromCache:chapterIndex] title];
    NSArray *currentPageModes = [self pageArrayFromCache:chapterIndex];
    NSString *comments = [NSString stringWithFormat:@"本章节有%ld条吐槽", (long)[self chapterModelFromCache:chapterIndex].commentCounts];
    
    LDTitleView *titleView = [[LDTitleView alloc] initWithTitle:title configuration:self.configuration];
   
    self.titleView = titleView;
    
    [target addSubview:titleView];
    
    LDStatusBarView *statusBV = [[LDStatusBarView alloc] initWithPageCounts:currentPageModes.count
                                                                  pageIndex:pageIndex
                                                               commentTitle:comments                                                              configuration:self.configuration];
    __weak typeof(self) weakSelf = self;
    statusBV.clickBlock = ^() {
        if ([weakSelf.delegate respondsToSelector:@selector(readerDidClickChapterComment:)]) {
            [weakSelf.delegate readerDidClickChapterComment:weakSelf];
        }
    };
    self.statusBarView = statusBV;
    [target addSubview:statusBV];
}

- (void)loadReaderView
{
    LDReaderScrollType scrollType = self.configuration.scrollType;
    switch (scrollType) {
        case LDReaderScrollCurl:
        case LDReaderScrollPagingHorizontal:
            [self loadPageViewController];
            break;
        case LDReaderScrollVertical:
        case LDReaderScrollPagingVertical:
            {
            BOOL isPagingAble = scrollType == LDReaderScrollVertical ? NO :YES;
            if (self.pageVC) {
                [self.pageVC willMoveToParentViewController:nil];
                [self.pageVC removeFromParentViewController];
                [self.pageVC.view removeFromSuperview];
                self.pageVC = nil;
            }
            if (!_tableView) {
                [self loadTableView];
            }
            _tableView.pagingEnabled = isPagingAble;
                _tableView.bounces = isPagingAble;
        }
            break;
        default:
            break;
    }
    if (self.configuration.backgroundImage) {
        [self setReaderBackgroundWithImage:YES];
    }else {
        [self setReaderBackgroundWithImage:NO];
    }
    [self.view.subviews makeObjectsPerformSelector:@selector(setBackgroundColor:) withObject:[UIColor clearColor]];
}


- (void)loadPageViewController
{
    if (self.pageVC) {
        [self.pageVC.view removeFromSuperview];
        [self.pageVC willMoveToParentViewController:nil];
        [self.pageVC removeFromParentViewController];
    }
    if (self.tableView) {
        [self.tableView removeFromSuperview];
        [self.titleView removeFromSuperview];
        [self.statusBarView removeFromSuperview];
        self.tableView = nil;
    }
    LDReaderScrollType scrollType = self.configuration.scrollType;
    UIPageViewControllerTransitionStyle transtionStyle = (scrollType == LDReaderScrollCurl) ? UIPageViewControllerTransitionStylePageCurl : UIPageViewControllerTransitionStyleScroll;
    self.pageVC = [[UIPageViewController alloc] initWithTransitionStyle:transtionStyle navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];
    self.pageVC.dataSource = self;
    self.pageVC.delegate = self;
    self.pageVC.view.backgroundColor = [UIColor clearColor];
    self.pageVC.doubleSided = (scrollType == LDReaderScrollCurl) ? YES : NO;
    if (scrollType == LDReaderScrollCurl) {
        for (UIGestureRecognizer *gr in self.pageVC.view.gestureRecognizers) {
            if ([gr isKindOfClass:[UITapGestureRecognizer class]]) {
                gr.delegate = self;
            }
        }
    }
    if (scrollType == LDReaderScrollPagingHorizontal) {
        UIScrollView *scroll = [self getScrollViewFromPageVC];
        scroll.delegate = self;
    }
    
    [self addChildViewController:self.pageVC];
    [self.view addSubview:self.pageVC.view];
    [self.pageVC didMoveToParentViewController:self];
}

- (void)loadTableView
{
    LDReaderScrollType scrollType = self.configuration.scrollType;
    BOOL pagingEnable = (scrollType == LDReaderScrollVertical) ? NO : YES;
    LDTableView *tableView = [[LDTableView alloc] initWithFrame:CGRectMake(0, self.configuration.contentFrame.origin.y,KScreenWidth, self.configuration.contentFrame.size.height) style:UITableViewStylePlain];
    
    self.tableView = tableView;
//    tableView.decelerationRate = 0.1;
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.showsVerticalScrollIndicator = NO;
    tableView.scrollsToTop = NO;
    tableView.backgroundColor = [UIColor clearColor];
    tableView.pagingEnabled = pagingEnable;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.rowHeight = self.configuration.contentFrame.size.height;
    tableView.estimatedRowHeight = 0;
    tableView.estimatedSectionFooterHeight = 0;
    tableView.estimatedSectionHeaderHeight = 0;
    [self.view addSubview:tableView];
    [self addTitleViewAndStatusViewTo:self.view];
}

- (void)setReaderBackgroundWithImage:(BOOL)isImage
{
    if (self.configuration.scrollType == LDReaderScrollPagingHorizontal || self.configuration.scrollType == LDReaderScrollCurl) {
        [self.backgroundImageView removeFromSuperview];
        self.backgroundImageView = nil;
        self.view.backgroundColor = [UIColor whiteColor];
        [LDPageViewController setBackGround:isImage configuration:self.configuration];
        
        LDPageViewController *curPage = self.pageVC.viewControllers.firstObject;
        if (curPage) {
            if (isImage) {
                if (!self.configuration.backgroundImage) {
                    return;
                }
                [curPage.backgroundImageView removeFromSuperview];
                curPage.backgroundImageView = [[UIImageView alloc] initWithFrame:CGRectMake(curPage.view.ld_x, curPage.view.ld_y, curPage.view.ld_width, curPage.view.ld_height)];
                curPage.backgroundImageView.image = self.configuration.backgroundImage;
                [curPage.view insertSubview:curPage.backgroundImageView atIndex:0];
                
            }else {
                [curPage.backgroundImageView removeFromSuperview];
                curPage.backgroundImageView = nil;
                curPage.view.backgroundColor = self.configuration.backgroundColor;
            }
        }
        
    }
//    else {
        if (isImage) {
            if (!self.configuration.backgroundImage) {
                [self.backgroundImageView removeFromSuperview];
                return;
            }
            if (!_backgroundImageView) {
                _backgroundImageView = [[UIImageView alloc]initWithFrame:self.view.bounds];
            }
            _backgroundImageView.image = self.configuration.backgroundImage;
            [self.view insertSubview:_backgroundImageView atIndex:0];
            self.view.backgroundColor = nil;
        }else {
            if (!self.configuration.backgroundColor) {
                return;
            }
            self.view.backgroundColor = self.configuration.backgroundColor;
            if (self.backgroundImageView) {
                [self.backgroundImageView removeFromSuperview];
                self.backgroundImageView = nil;
            }
        }
//    }
    
}

- (void)readPage:(NSInteger)index
{
    index = index < 0 ? 0 : index;
   
    switch (self.configuration.scrollType) {
        case LDReaderScrollCurl:
        case LDReaderScrollPagingHorizontal:
        {
            LDPageViewController *page = [self getPageVCWithIndex:index];
            if (!page) {
                DFLog(WARNING, @"page is nil. @%s", __FUNCTION__);
                return;
            }
            /*remain*/
            [page.view removeFromSuperview];
            [page willMoveToParentViewController:nil];
            [page removeFromParentViewController];
            
            __weak typeof(self) weakSelf = self;
            [self.pageVC setViewControllers:@[page] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:^(BOOL finished) {
                if ([weakSelf.delegate respondsToSelector:@selector(reader:currentPageWithPageString:)] /*&& !weakSelf.pageTurningByTap*/) {
                    //水平翻页点击翻页模式下回调；第一次进入阅读器不会走finished回调，故也在这里回调
                    for (UIView *view in page.view.subviews) {
                        if ([view isKindOfClass:[LDAttributedLabel class]]) {
                            weakSelf.currentAttributeLabel = (LDAttributedLabel *)view;
                            break;
                        }
                    }
                    [weakSelf.delegate reader:weakSelf currentPageWithPageString:[weakSelf.currentAttributeLabel.attributedString string]];
                }
            }];
            _currentPageIndex = index;
        }
            break;
        case LDReaderScrollVertical:
        case LDReaderScrollPagingVertical:
        {
            if (!self.tableViewDataArray.count) return;
            if (self.manualJumpChapterOrPage && !self.isJumpChapter) {
                
            }else{
                [self.tableView reloadData];
            }
            CGFloat contentOffset = 0;
            if (self.configuration.scrollType == LDReaderScrollVertical) {
                contentOffset = _currentCellIndex*self.tableView.ld_height + [self addOffsetWithPreChapterIndex:_currentChapterIndex - 1];
                }else{
                    contentOffset = index * self.tableView.ld_height;
                }
                [self.tableView setContentOffset:CGPointMake(0, contentOffset) animated:NO];
        }
            break;
        default:
            break;
    }
}

- (void)addGestureRecognizerAndCallback{
    [self addGestureRecognizer];
    if ([self.delegate respondsToSelector:@selector(reader:progressWithChapter:pageCounts:pageIndex:currentWordIndex:)] && self.configuration.hasCover) {
        NSArray *array = [self pageArrayFromCache:self.currentChapterIndex];
        LDPageModel *pageModel = array[_currentPageIndex];
        [self.delegate reader:self progressWithChapter:self.currentChapterIndex pageCounts:array.count pageIndex:self.currentPageIndex + 1 currentWordIndex:pageModel.range.location];
    }
}

- (void)loadCoverImage
{
    UIView *baseView = [[UIView alloc] init];
    baseView.center = CGPointMake(self.view.center.x, self.view.center.y);
    baseView.bounds = CGRectMake(0, 0, self.view.ld_width, self.view.ld_height);
    baseView.backgroundColor = [UIColor whiteColor];
    
    if (self.configuration.backgroundImage) {
        UIImageView *baseImageView = [[UIImageView alloc]initWithFrame:baseView.bounds];
        baseImageView.image = self.configuration.backgroundImage;
        [baseView addSubview:baseImageView];
    }
    
    
    UIImageView *imageView = [[UIImageView alloc]initWithFrame:CGRectMake(KZoom_Scale_X*13, KZoom_Scale_Y*20, KScreenWidth-2*KZoom_Scale_X*13, KScreenHeight-2*KZoom_Scale_Y*20)];
    NSBundle *resourceBundle = [NSBundle bundleWithPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"LDResource" ofType:@"bundle"]];
    NSString *filePath;
    if (self.configuration.textColor == [UIColor whiteColor]) {
       filePath = [resourceBundle pathForResource:@"backgroundImage_night" ofType:@"png"];
    }else{
       filePath = [resourceBundle pathForResource:@"backgroundImage" ofType:@"png"];
    }
    
    UIImage *backgroundImage = [UIImage stretchedImageWithPath:filePath];
    imageView.image = backgroundImage;
    [baseView addSubview:imageView];
    
    
    // 书名
    UILabel *name = [UILabel new];
    CGFloat fontSize = self.bookModel.coverImage ? 20 :30;
    name.font = [UIFont fontWithName:@"PingFangSC-Semibold" size:fontSize];
    name.text = self.bookModel.name;
    
    name.numberOfLines = 0;
    [name sizeToFit];
    [baseView addSubview:name];
    
    //作者名
    UILabel *author = [UILabel new];
    author.font = [UIFont fontWithName:@"PingFangSC-Regular" size:14];
    author.text = [NSString stringWithFormat:@"%@", self.bookModel.author];
    author.numberOfLines = 0;
    [author sizeToFit];
    [baseView addSubview:author];
    if (self.configuration.textColor == [UIColor whiteColor]) {
        name.textColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.5];
        author.textColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.4];
    }else{
        name.textColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
        author.textColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.4];
    }
    
    if (self.bookModel.coverImage) {
        CGFloat x = KZoom_Scale_X * 110;
        CGFloat y = KZoom_Scale_Y * 105;
        UIImageView *cover = [[UIImageView alloc]initWithImage:self.bookModel.coverImage];
        cover.frame = (CGRect){.origin = {x,y},.size = {156*KZoom_Scale_X,221*KZoom_Scale_Y}};
        [baseView addSubview:cover];
        
        //书名
        CGFloat coverMaxY = CGRectGetMaxY(cover.frame);
        name.frame = (CGRect){.origin = {61*KZoom_Scale_X,24 * KZoom_Scale_Y+coverMaxY},.size = {KScreenWidth-2*61*KZoom_Scale_X,name.ld_height}};
        name.textAlignment = NSTextAlignmentCenter;
        
        //作者名
        CGFloat nameMaxY = CGRectGetMaxY(name.frame);
        author.frame = (CGRect){.origin = {name.ld_x,nameMaxY+14*KZoom_Scale_Y},.size = {name.ld_width,author.ld_height}};
        author.textAlignment = NSTextAlignmentCenter;
        
    }else{
        //书名
        name.frame = CGRectMake(58*KZoom_Scale_X, 200*KZoom_Scale_Y, KScreenWidth-2*58*KZoom_Scale_X, name.ld_height);
        name.textAlignment = NSTextAlignmentLeft;
        
        
        //作者名
        CGFloat nameMaxY = CGRectGetMaxY(name.frame);
        author.frame = (CGRect){.origin = {name.ld_x,nameMaxY+14*KZoom_Scale_Y},.size = {name.ld_width,author.ld_height}};
        author.textAlignment = NSTextAlignmentLeft;
    }

    NSString *starFilePath;
    if (self.configuration.textColor == [UIColor whiteColor]) {
        starFilePath = [resourceBundle pathForResource:@"fivePointedStar_night" ofType:@"png" inDirectory:@"LDResource.bundle"];
    }else{
        starFilePath = [resourceBundle pathForResource:@"fivePointedStar" ofType:@"png" inDirectory:@"LDResource.bundle"];
    }
    
    UIImageView *starImageView = [[UIImageView alloc]initWithImage:[UIImage imageWithContentsOfFile:starFilePath]];
    starImageView.ld_size = CGSizeMake(125, 5);
    starImageView.center = CGPointMake(KScreenWidth/2, KScreenHeight-100*KZoom_Scale_Y);
    [baseView addSubview:starImageView];
    
    //版权声明
    UILabel *bookCopyRight1 = [[UILabel alloc]init];
    if (self.bookModel.copyright) {
        bookCopyRight1.text = [NSString stringWithFormat:@"%@",self.bookModel.copyright];
    }else{
        bookCopyRight1.text = @"本书由上海元聚进行电子本制作与发行";

    }
    [bookCopyRight1 sizeToFit];
    bookCopyRight1.center = CGPointMake(KScreenWidth/2,CGRectGetMaxY(starImageView.frame)+ 5+bookCopyRight1.ld_height*.5);
    bookCopyRight1.numberOfLines = 0;
    bookCopyRight1.textColor = [UIColor grayColor];
    bookCopyRight1.textAlignment = NSTextAlignmentCenter;
    bookCopyRight1.font = [UIFont systemFontOfSize:10];
    [baseView addSubview:bookCopyRight1];
    
    UILabel *copyright2 = [[UILabel alloc]init];
    copyright2.text = @"版权所有·侵权必究";
    copyright2.textColor = [UIColor grayColor];
    copyright2.font = [UIFont systemFontOfSize:10];
    [copyright2 sizeToFit];
    copyright2.center = CGPointMake(KScreenWidth/2, CGRectGetMaxY(bookCopyRight1.frame) + 5+ copyright2.ld_height*.5);
    [baseView addSubview:copyright2];
    [self.view addSubview:baseView];
    
    UITapGestureRecognizer *pagingTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(didClickCover:)];
    [baseView addGestureRecognizer:pagingTap];
}

#pragma mark - 封面点击回调

- (void)didClickCover:(UITapGestureRecognizer *)gr
{
    [UIView animateWithDuration:0.3 animations:^() {
        gr.view.frame = CGRectMake(gr.view.ld_x - gr.view.ld_width, gr.view.ld_y, gr.view.ld_width, gr.view.ld_height);
    } completion:^(BOOL finished) {
        [gr.view removeFromSuperview];
        [self addGestureRecognizerAndCallback];
    }];
}

#pragma mark - Setter Method

//为了设置当前显示的章节index
-(void)setCurrentChapterIndex:(NSInteger)currentChapterIndex
{
    if (_currentChapterIndex == currentChapterIndex) return;
    
    /*以下三行顺序不能修改！*/
    BOOL isForward = (currentChapterIndex > _currentChapterIndex) ? YES : NO;
    _currentChapterIndex = currentChapterIndex;
    LDChapterModel *currentModel = [self chapterModelFromCache:_currentChapterIndex];
    self.statusBarView.commentTitle = [NSString stringWithFormat:@"本章节有%ld条吐槽", (long)currentModel.commentCounts];
    if ([self.delegate respondsToSelector:@selector(reader:currentChapterWithPages:currentChapterIndex:)] && [self pageArrayFromCache:_currentChapterIndex].count) {
        NSMutableArray *pageArray = [NSMutableArray array];
        for (LDPageModel *pageModel in [self pageArrayFromCache:_currentChapterIndex]) {
            [pageArray addObject:pageModel.pageString];
        }
        [self.delegate reader:self currentChapterWithPages:pageArray currentChapterIndex:_currentChapterIndex];
    }
    [self forwardCacheIfNeed:isForward];
}

- (void)setChapterTitle
{
    if (self.tableView) {
        if (!_currentPageIndex) {
            self.titleView.title = self.bookModel.name;
        }else{
            LDChapterModel *currentModel = [self chapterModelFromCache:_currentChapterIndex];
            self.titleView.title = currentModel.title;
        }
        
    }
}

-(void)setSelectedParagraphIndex:(NSInteger)selectedParagraphIndex
{
    _selectedParagraphIndex = selectedParagraphIndex;
    self.currentAttributeLabel.selectedParagraphIndex = selectedParagraphIndex;
}

-(void)setConfiguration:(LDConfiguration *)configuration
{
    if(!_configuration){
        _configuration = configuration;
        return;
    }else{
        _configuration.settingFrame = configuration.settingFrame;
        _configuration.prePageFrames = configuration.prePageFrames;
        _configuration.nextPageFrames = configuration.nextPageFrames;
//        _configuration.chapterTitleFont = configuration.chapterTitleFont;
        _configuration.chapterTitleAlignment = configuration.chapterTitleAlignment;
        _configuration.commentEntryEnable = configuration.commentEntryEnable;
        _configuration.hasCover = configuration.hasCover;
        _configuration.autoSelectedParagraphColor = configuration.autoSelectedParagraphColor;
        _configuration.maxCacheSize = configuration.maxCacheSize;
    }
    _unifiedSetting = YES;
    _configuration.fontSize = configuration.fontSize;
    _configuration.lineSpacing = configuration.lineSpacing;
    _configuration.fontName = configuration.fontName;
    _configuration.isSimple = configuration.isSimple;
    _configuration.advertisingIndex = configuration.advertisingIndex;
    
    __weak typeof(_configuration) weakConfiguration = _configuration;
    self.unifiedSettingBlock = ^{
        weakConfiguration.textColor = configuration.textColor;
        weakConfiguration.scrollType = configuration.scrollType;
        weakConfiguration.themeColor = configuration.themeColor;
        if (configuration.backgroundImage) {
            weakConfiguration.backgroundImage = configuration.backgroundImage;
        }else{
            weakConfiguration.backgroundColor = configuration.backgroundColor;
        }
    };
    
    if (_unifiedSettingKey) {
        _neddUnifiedSetting = YES;
        [_configuration setValue:_unifiedSettingValue forKey:_unifiedSettingKey];
    }else{//兼容只进行单个非重分页设置,也通过重新创建configuration的方式设置
        _unifiedSettingWithNoRecute = YES;
        if (self.unifiedSettingBlock) {
            self.unifiedSettingBlock();
        }
        _unifiedSetting = NO;
        _unifiedSettingWithNoRecute = NO;
    }
}


#pragma mark - 数据处理

- (LDPageViewController *)getPageVCWithIndex:(NSInteger)index
{
    return [self getPageVCWithIndex:index inChapter:self.currentChapterIndex];
}

- (LDPageViewController *)getPageVCWithIndex:(NSInteger)index inChapter:(NSInteger)chapterIndex
{
    LDPageViewController *page = [[LDPageViewController alloc] init];
    page.index = index;
    page.chapterBelong = chapterIndex;
    LDAttributedLabel *dtLabel = [[LDAttributedLabel alloc] initWithFrame:self.configuration.contentFrame andConfiguration:self.configuration];
    dtLabel.readerView = self.view;
    dtLabel.ld_x = 0;
    dtLabel.ld_width = KScreenWidth;
    dtLabel.edgeInsets = UIEdgeInsetsMake(0, _configuration.contentFrame.origin.x, 0, _configuration.contentFrame.origin.x);
    
    
    NSMutableArray *chapArray = [self pageArrayFromCache:chapterIndex];
    if (!chapArray) {
        DFLog(WARNING, @"chapter %d array is nil", chapterIndex);
        return nil;//无此章节数据（比如到达了书籍的最后一章）
    }
    LDPageModel *pageModel = chapArray[index];
    __weak typeof(self) weakSelf = self;
    if (self.menuTitles.count) {
        dtLabel.menuTitles = self.menuTitles;
        [dtLabel setMenuItemClockClick:^(NSString *title, NSString *contentStr, NSRange range) {
            [weakSelf menuItemDidClickWithTitle:title andSelectedRange:range andPageModel:pageModel];
            if ([weakSelf.delegate respondsToSelector:@selector(reader:menuItemClickWithTitle:andContentString: andSelectedRange:)]) {
                [weakSelf.delegate reader:weakSelf menuItemClickWithTitle:title andContentString:contentStr andSelectedRange:range];
            }
        }];
    }
    NSAttributedString *tmpAttr = [pageModel.attrString convertToAttributedString:self.configuration];
    NSAttributedString *newAttr = [pageModel.attrString autoReserveModeColorWithAttributeString:tmpAttr];
    dtLabel.attributedString = newAttr ? newAttr : tmpAttr;
    dtLabel.backgroundColor = [UIColor clearColor];
    dtLabel.rangeInChapter = pageModel.range;
    dtLabel.markList = pageModel.markArray;
    [page.view addSubview:dtLabel];
    
    if (index == [self pageArrayFromCache:chapterIndex].count - 1) {
        UIView *tailView = [self getChapterTailView:dtLabel chapterIndex:chapterIndex];
        [dtLabel addSubview:tailView];
    }
    
    // 添加广告
    if (pageModel.advertising) {
        UIView *advertisingView = [self getAdvertisingView:dtLabel chapterIndex:chapterIndex andPageIndex:pageModel.pageIndex];
        [dtLabel addSubview:advertisingView];
    }

    [self addTitleViewAndStatusViewTo:page.view atPageIndex:index atChapterIndex:chapterIndex];
//    LDChapterModel *currentModel = chapterModelCaches[[LDUtil toString:chapterIndex]];
//    self.titleView.title = currentModel.title;
    return page;
}

- (void)requestChapterWithIndex:(NSInteger)chapterIndex
{
    if (self.fedByWholeBook) {
        [self feedReaderWithLocalChapter:chapterIndex];
        return;
    }
    if ([self.chapterCacheFlags objectForKey:@(chapterIndex)]) {
        DLog(@"the chapter is cached or caching!");
        return;
    }
    if ([self.delegate respondsToSelector:@selector(reader:needChapterWithIndex:)]) {
        DLog(@"request chapter %ld", (long)chapterIndex);
        [self.delegate reader:self needChapterWithIndex:chapterIndex];
    }
}

- (UIView *)getChapterTailView:(DTAttributedTextContentView *)contentView chapterIndex:(NSInteger)chapterIndex
{
    DTCoreTextLayoutFrame *frame = [contentView layoutFrame];
    CGRect rect = [frame intrinsicContentFrame];
    CGRect tailRect = CGRectMake(self.configuration.contentFrame.origin.x, rect.size.height, self.configuration.contentFrame.size.width, self.configuration.contentFrame.size.height - rect.size.height);
    UIView *view = [[UIView alloc] initWithFrame:tailRect];
    if ([self.delegate respondsToSelector:@selector(reader:chapterTailView:chapterIndex:)]) {
        [self.delegate reader:self chapterTailView:view chapterIndex:chapterIndex];
    }
    return view;
}

- (UIView *)getAdvertisingView:(DTAttributedTextContentView *)contentView chapterIndex:(NSInteger)chapterIndex andPageIndex:(NSInteger)pageIndex
{
    DTCoreTextLayoutFrame *frame = contentView.layoutFrame;
    CGFloat advertingY = frame.advertisingTop + (frame.advertisingBottom-frame.advertisingTop-advertisingHeight_)/2.0;
    UIView *advertisingView = [[UIView alloc]initWithFrame:(CGRect){.origin = CGPointMake(self.configuration.contentFrame.origin.x, advertingY),.size = CGSizeMake(self.configuration.contentFrame.size.width, advertisingHeight_)}];
    if ([self.delegate respondsToSelector:@selector(reader:advertisingView:chapterIndex:andPageIndex:)]) {
        [self.delegate reader:self advertisingView:advertisingView chapterIndex:chapterIndex andPageIndex:pageIndex+1];
    }
    return advertisingView;
}

- (void)feedReaderWithLocalChapter:(NSInteger)chapterIndex
{
    DFLog(INFO, @"feedReaderWithLocalChapter");
    LDChapterModel *chapter = [LDChapterModel new];
    chapter.chapterIndex = chapterIndex;
//    NSString *document = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
//    NSString *storePath = [document stringByAppendingPathComponent:@"ldreader-books"];
//    NSString *bookPath = [NSString stringWithFormat:@"%@/%@", storePath, MD5STR];
    NSString *chapterPath = [NSString stringWithFormat:@"%@/chapter%ld.txt", _bookPath, (long)chapterIndex];
    if (![[NSFileManager defaultManager] fileExistsAtPath:chapterPath]) {
        return;
    }
    chapter.path = chapterPath;
    chapter.title = [wholeBookChapterTitles_[chapterIndex-1] objectForKey:@"title"];
    chapter.commentCounts = 890;
    [self readWithChapter:chapter pageIndex:1];
}

- (UIScrollView *)getScrollViewFromPageVC
{
    UIScrollView *scroll = nil;
    for (UIView *view in self.pageVC.view.subviews) {
        if ([view isKindOfClass:[UIScrollView class]]) {
            scroll = (UIScrollView *)view;
            break;
        }
    }
    return scroll;
}

#pragma mark - 点击切换上下页

- (void)addGestureRecognizer
{
    UITapGestureRecognizer *pagingTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(pagingTap:)];
    [self.view addGestureRecognizer:pagingTap];
}

- (void)pagingTap:(UITapGestureRecognizer *)pagingTap
{
    CGPoint tapPoint = [pagingTap locationInView:self.view];
    if (CGRectContainsPoint(self.configuration.settingFrame, tapPoint)) {//设置
        if ([self.delegate respondsToSelector:@selector(readerDidClickSettingFrame:)]) {
            [self.delegate readerDidClickSettingFrame:self];
        }
        return;
    }
    [self.configuration.prePageFrames enumerateObjectsUsingBlock:^(id  _Nonnull PreFrameValue, NSUInteger idx, BOOL * _Nonnull stop) {
        CGRect prePageFrame = [PreFrameValue CGRectValue];
        if (CGRectContainsPoint(prePageFrame, tapPoint)) {//上一页
            [self prePage];
            return;
        }
    }];
    
    [self.configuration.nextPageFrames enumerateObjectsUsingBlock:^(id  _Nonnull nextFrameValue, NSUInteger idx, BOOL * _Nonnull stop) {
        CGRect nextPageFrame = [nextFrameValue CGRectValue];
        if (CGRectContainsPoint(nextPageFrame, tapPoint)) {//下一页
            [self nextPage];
            return;
        }
    }];
}

- (void)prePage
{
    DLog(@"go to last page");
    switch (_configuration.scrollType) {
        case LDReaderScrollVertical:
            break;
        case LDReaderScrollPagingVertical:
            [self readerPagingIsNext:NO WithAnimation:YES];
            break;
        case LDReaderScrollCurl:
        {
            self.view.userInteractionEnabled = NO;
            LDPageViewController *curPage = self.pageVC.viewControllers.firstObject;
            UIViewController *backVC = [self lastVCBeforeViewController:curPage];
            if (!backVC) {
                DFLog(WARNING, @"back vc is nil. @%s", __FUNCTION__);
                self.view.userInteractionEnabled = YES;
                return;
            }
            UIViewController *frontVC = [self lastVCBeforeViewController:backVC];
            if (!frontVC) {
                DFLog(WARNING, @"front vc is nil. @%s", __FUNCTION__);
                self.view.userInteractionEnabled = YES;
                return;
            }
            
            __weak __typeof__(self) weakSelf = self;
            [self.pageVC setViewControllers:@[frontVC,backVC] direction:UIPageViewControllerNavigationDirectionReverse animated:YES completion:^(BOOL finished) {
                if (finished) {
                    __typeof__(weakSelf) strongSelf = weakSelf;
                    [strongSelf pageViewControllerDidFinishedTransition:strongSelf.pageVC previousViewController:curPage];
                    strongSelf.view.userInteractionEnabled = YES;
                }
            }];
            
            break;
        }
        case LDReaderScrollPagingHorizontal:
        {
            if (self.currentPageIndex == 0 && self.currentChapterIndex == 1) {
                if (self.delegate && [self.delegate respondsToSelector:@selector(reader:failedWithError:)]) {
                    [self.delegate reader:self failedWithError:[NSError errorWithDomain:@"ldreader" code:-8003 userInfo:@{NSLocalizedFailureReasonErrorKey:@"arrived first page."}]];
                    isCallback = YES;
                }
            }
            self.pageTurningByTap = YES;
//            self.view.userInteractionEnabled = NO;
            UIViewController *currentPage = self.pageVC.viewControllers.firstObject;
            UIViewController *page = [self lastVCBeforeViewController:currentPage];
            UIImage *image = [LDUtil imageFromViewController:currentPage];
            if (!page) {
                DFLog(WARNING, @"pre page is nil. @%s", __FUNCTION__);
                self.pageTurningByTap = NO;
//                self.view.userInteractionEnabled = YES;
                return;
            }
            [page.view removeFromSuperview];
            [page willMoveToParentViewController:nil];
            [page removeFromParentViewController];
            
            __weak __typeof__(self) weakSelf = self;
            [self.pageVC setViewControllers:@[page] direction:UIPageViewControllerNavigationDirectionReverse animated:NO completion:^(BOOL finished) {
                __typeof__(weakSelf) strongSelf = weakSelf;
                [strongSelf pageViewControllerDidFinishedTransition:strongSelf.pageVC previousViewController:currentPage];
                /*这里禁用系统动画后会导致使用正常拖动切换页面失败，解决方案是每次通过点击的方式切换页面后reload pageVC*/
                [strongSelf loadPageViewController];
                [strongSelf readPage:strongSelf.currentPageIndex];
                strongSelf.pageTurningByTap = NO;
                if (strongSelf.currentPageIndex == 0) {
                    [strongSelf lastVCBeforeViewController:strongSelf.pageVC.viewControllers.firstObject];
                }
            }];
            /*自定义水平滑动动画*/
            CGRect oldFrame = self.pageVC.view.frame;
            UIImageView *imageView = [[UIImageView alloc] initWithFrame:oldFrame];
            imageView.image = image;
            CGRect newFame = CGRectOffset(oldFrame, oldFrame.size.width, 0);
            [self.view insertSubview:imageView belowSubview:page.view];
//            [self.view insertSubview:imageView atIndex:0];
            self.pageVC.view.frame = CGRectMake(self.pageVC.view.ld_x - self.pageVC.view.ld_width, self.pageVC.view.ld_y, self.pageVC.view.ld_width, self.pageVC.view.ld_height);
            [UIView animateWithDuration:0.2 animations:^() {
                self.pageVC.view.frame = oldFrame;
                imageView.frame = newFame;
            } completion:^(BOOL finished) {
                [imageView removeFromSuperview];
//                self.view.userInteractionEnabled = YES;
            }];
            break;
        }
        default:
            break;
    }
}

- (void)nextPage
{
    DLog(@"go to next page");
    switch (_configuration.scrollType) {
        case LDReaderScrollVertical:
            break;
        case LDReaderScrollPagingVertical:
            [self readerPagingIsNext:YES WithAnimation:YES];
            break;
        case LDReaderScrollCurl:
        {
            self.view.userInteractionEnabled = NO;
            LDPageViewController *curPage = self.pageVC.viewControllers.firstObject;
            UIViewController *backVC = [self nextVCAfterViewController:curPage];
            UIViewController *frontVC = [self nextVCAfterViewController:backVC];
            if (!frontVC) {
                DFLog(WARNING, @"front vc is nil. @%s", __FUNCTION__);
                self.view.userInteractionEnabled = YES;
                return;
            }
            
            __weak __typeof__(self) weakSelf = self;
            [self.pageVC setViewControllers:@[frontVC,backVC] direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:^(BOOL finished) {
                if (finished) {
                    __typeof__(weakSelf) strongSelf = weakSelf;
                    [strongSelf pageViewControllerDidFinishedTransition:strongSelf.pageVC previousViewController:curPage];
                    strongSelf.view.userInteractionEnabled = YES;
                }
            }];
            
            break;
        }
        case LDReaderScrollPagingHorizontal:
        {
            if (self.currentPageIndex == [self pageArrayFromCache:self.currentChapterIndex].count - 1) {
                if (self.delegate && [self.delegate respondsToSelector:@selector(reader:failedWithError:)]) {
                    [self.delegate reader:self failedWithError:[NSError errorWithDomain:@"ldreader" code:-8004 userInfo:@{NSLocalizedFailureReasonErrorKey:@"arrived last page."}]];
                }
            }
            self.pageTurningByTap = YES;
//            self.view.userInteractionEnabled = NO;
            UIViewController *currentPage = self.pageVC.viewControllers.firstObject;
            UIViewController *page = [self nextVCAfterViewController:currentPage];
            UIImage *image = [LDUtil imageFromViewController:currentPage];
            if (!page)  {
                DFLog(WARNING, @"next page is nil. @%s", __FUNCTION__);
                self.pageTurningByTap = NO;
//                self.view.userInteractionEnabled = YES;
                return;
            }
            
            [page.view removeFromSuperview];
            [page willMoveToParentViewController:nil];
            [page removeFromParentViewController];
            
            __weak __typeof__(self) weakSelf = self;
            [self.pageVC setViewControllers:@[page] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:^(BOOL finished) {
                __typeof__(weakSelf) strongSelf = weakSelf;
                [strongSelf pageViewControllerDidFinishedTransition:strongSelf.pageVC previousViewController:currentPage];
                /*这里禁用系统动画后会导致使用正常拖动切换页面失败，解决方案是每次通过点击的方式切换页面后reload pageVC*/
                [strongSelf loadPageViewController];
                [strongSelf readPage:strongSelf.currentPageIndex];
                strongSelf.pageTurningByTap = NO;
                if (self.currentPageIndex == [strongSelf pageArrayFromCache:strongSelf.currentChapterIndex].count - 1) {
                    [strongSelf nextVCAfterViewController:strongSelf.pageVC.viewControllers.firstObject];
                }
            }];
            /*自定义水平滑动动画*/
            CGRect oldFrame = self.pageVC.view.frame;
            CGRect newFrame = CGRectOffset(oldFrame, -oldFrame.size.width, 0);
            UIImageView *imageView = [[UIImageView alloc] initWithFrame:oldFrame];
            imageView.image = image;
            [self.view insertSubview:imageView belowSubview:page.view];
//            [self.view insertSubview:imageView atIndex:0];
            
            self.pageVC.view.frame = CGRectMake(self.pageVC.view.ld_x + self.pageVC.view.ld_width, self.pageVC.view.ld_y, self.pageVC.view.ld_width, self.pageVC.view.ld_height);
            [UIView animateWithDuration:0.2 animations:^() {
                self.pageVC.view.frame = oldFrame;
                imageView.frame = newFrame;
            } completion:^(BOOL finished) {
                [imageView removeFromSuperview];
//                self.view.userInteractionEnabled = YES;
            }];
            
            break;
        }
        default:
            break;
    }
}

/**
 翻页
 */
-(void)readerPagingIsNext:(BOOL)isNext WithAnimation:(BOOL)isAnimation
{
    if (self.currentPageIndex == 0 && self.currentChapterIndex == 1 && !isNext) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(reader:failedWithError:)]) {
            [self.delegate reader:self failedWithError:[NSError errorWithDomain:@"ldreader" code:-8003 userInfo:@{NSLocalizedFailureReasonErrorKey:@"arrived first page."}]];
            isCallback = YES;
        }
    }
    if (self.currentPageIndex == [self pageArrayFromCache:self.currentChapterIndex].count - 1 && isNext) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(reader:failedWithError:)]) {
            [self.delegate reader:self failedWithError:[NSError errorWithDomain:@"ldreader" code:-8004 userInfo:@{NSLocalizedFailureReasonErrorKey:@"arrived last page."}]];
        }
    }
    NSInteger scrollIndex ;
    scrollIndex = isNext ? _currentCellIndex +1 : _currentCellIndex -1;
    DLog(@"点击翻页 _currentCellIndex == %zd,tableViewDataArray == %zd",_currentCellIndex,self.tableViewDataArray.count);
    if (scrollIndex < 0 || scrollIndex >= self.tableViewDataArray.count)
    {
        [self updateReaderStateWithIsNext:isNext];
        return;
    }
    self.view.userInteractionEnabled = NO;
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:scrollIndex inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:isAnimation];
}

#pragma mark - Getter Method

- (LDDataParser *)dataParser
{
    if (!_dataParser) {
        switch (self.configuration.bookType) {
            case LDBookText:
                _dataParser = [[NSClassFromString(@"LDTextDataParser") alloc] init];
                
                break;
            case LDBookEpub:
                break;
            default:
                break;
        }
    }
    return _dataParser;
}

- (LDConfiguration *)configuration
{
    if (!_configuration) {
        _configuration = [LDConfiguration shareConfiguration];
//        SEL sel = NSSelectorFromString(@"defaultConfiguration");
//        IMP imp = [LDConfiguration instanceMethodForSelector:sel];
//        void (*defaultConfigurationFunc)(id, SEL) = (void(*)(id, SEL))imp;
//        defaultConfigurationFunc(_configuration, sel);
    }
    return _configuration;
}

- (dispatch_queue_t)cacheQueue
{
    if (!_cacheQueue) {
        _cacheQueue = dispatch_queue_create("ldreader.cache.queue", 0);
    }
    
    return _cacheQueue;
}

-(NSMutableArray *)tableViewDataArray
{
    if (!_tableViewDataArray) {
        _tableViewDataArray = [NSMutableArray array];
    }
    return _tableViewDataArray;
}

- (LDChapterModel *)chapterModel
{
    return [self chapterModelFromCache:self.currentChapterIndex];
}

-(NSMutableDictionary *)markBookCacheDic
{
    if (!_markBookCacheDic) {
        _markBookCacheDic = [NSMutableDictionary dictionary];
    }
    return _markBookCacheDic;
}

-(NSMutableDictionary *)lastCommentViewHeightDic
{
    if (!_lastCommentViewHeightDic) {
        _lastCommentViewHeightDic = [NSMutableDictionary dictionary];
    }
    return _lastCommentViewHeightDic;
}

-(NSMutableArray *)markChapterArray
{
    if (!_markChapterArray) {
        _markChapterArray = [NSMutableArray array];
    }
    return _markChapterArray;
}

#pragma mark - KVO
- (void)addObserverForConfiguration
{
    self.observeKeyPaths = @[@"fontSize",@"lineSpacing",@"scrollType",@"backgroundImage",@"backgroundColor",@"fontName",@"textColor",@"themeColor",@"isSimple",@"advertisingIndex"];
    for (NSString *path in self.observeKeyPaths) {
        [self.configuration addObserver:self forKeyPath:path options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if([keyPath isEqualToString:@"fontSize"] ||
       [keyPath isEqualToString:@"lineSpacing"] ||
       [keyPath isEqualToString:@"fontName"] ||
       [keyPath isEqualToString:@"isSimple"] ||
       [keyPath isEqualToString:@"advertisingIndex"]){
       //需要重分页
//        fabsf([change[NSKeyValueChangeNewKey] floatValue]-[change[NSKeyValueChangeOldKey] floatValue]) <= .01
        
        if ([change[NSKeyValueChangeNewKey] isEqual:change[NSKeyValueChangeOldKey]] && !_unifiedSettingKey) {
            return;
        }
        if (_unifiedSetting && !_neddUnifiedSetting) {//检测四个重分页属性
            _unifiedSettingKey = keyPath;
            _unifiedSettingValue = change[NSKeyValueChangeNewKey];
            return;
        }else if(_neddUnifiedSetting){
            _neddUnifiedSetting = NO;
            _unifiedSettingKey = NULL;
            _unifiedSettingValue = NULL;
        }
        if (self.state == LDReaderBusy) return;
        if (_configuration.scrollType == LDReaderScrollVertical && [self visibleCellsCount] > 1) {
            self.tableView.isRemoved = YES;
        }
        self.isReCutChapter = YES;
        self.tableView.isReCute = YES;
        self.tableView.preEndCellIndex = -1;
        if (self.startLocationPreviousPage == -1) {
            NSArray *pageArray = [self pageArrayFromCache:self.currentChapterIndex];
            LDPageModel *pageModel = pageArray[self.currentPageIndex];
            self.startLocationPreviousPage = pageModel.range.location;
        }
        LDChapterModel *chapterModel = [self chapterModelFromCache:_currentChapterIndex];
        [self readWithChapter:chapterModel pageIndex:_currentPageIndex];
    }else if ([keyPath isEqualToString:@"scrollType"]) {
        
        if ([change[NSKeyValueChangeNewKey] integerValue] == [change[NSKeyValueChangeOldKey] integerValue]) {
            return;
        }
        if (_unifiedSetting && !_unifiedSettingWithNoRecute) {
            return;
        }
        if (([change[NSKeyValueChangeOldKey] integerValue] == 2 &&
             [change[NSKeyValueChangeNewKey] integerValue] == 3) ||
            ([change[NSKeyValueChangeOldKey] integerValue] == 3 &&
             [change[NSKeyValueChangeNewKey] integerValue] == 2)) {
                self.tableView.isReloadTableView = YES;
            }
//        fabs(_currentCellIndex*self.tableView.ld_height - self.tableView.contentOffset.y)>=0.01
        if (_configuration.scrollType == LDReaderScrollPagingVertical && [self visibleCellsCount] > 1) {
            self.tableView.isRemoved = YES;
        }
        [self loadReaderView];
        if (self.tableView) {
             self.pageHunger = NO;
            [self setCurrentCellIndexAndTableViewDatas];
            [self readPage:_currentCellIndex];
        }else {
            [self readPage:self.currentPageIndex];
        }
    }else if ([keyPath isEqualToString:@"themeColor"] ||
              [keyPath isEqualToString:@"textColor"]) {
        if ([change[NSKeyValueChangeNewKey] isEqual:change[NSKeyValueChangeOldKey]]) {
            return;
        }
        if (_unifiedSetting && !_unifiedSettingWithNoRecute) {
            return;
        }
        if ([keyPath isEqualToString:@"textColor"]) {
            if (_configuration.scrollType == LDReaderScrollPagingVertical && [self visibleCellsCount] > 1) {
                self.tableView.isRemoved = YES;
            }
            self.tableView.isReloadTableView = YES;
            _preTextColor = change[NSKeyValueChangeOldKey];
        }
        if (self.tableView) {
            self.pageHunger = NO;
            [self setCurrentCellIndexAndTableViewDatas];
            [self readPage:_currentCellIndex];
        }else {
            [self readPage:self.currentPageIndex];
        }
    }
    else if ([keyPath isEqualToString:@"backgroundColor"]) {
        if (_unifiedSetting && !_unifiedSettingWithNoRecute) {
            return;
        }
        [self setReaderBackgroundWithImage:NO];
        self.configuration.backgroundImage = nil;
    }else if ([keyPath isEqualToString:@"backgroundImage"]) {
        if (_unifiedSetting && !_unifiedSettingWithNoRecute) {
            return;
        }
        //添加背景图片
        [self setReaderBackgroundWithImage:YES];
    }
}

#pragma mark - resetting
- (void)resettingReaderConfigurationWithDictionary:(NSDictionary *)dictionary
{
    LDConfiguration *configuration = [self.configuration copy];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [configuration setValue:obj forKey:key];
    }];
    self.configuration = configuration;
}

#pragma mark - Cache

- (void)cacheChapterWithIndex:(NSInteger)chapterIndex withObject:(id)object
{
    NSString *indexString = [LDUtil toString:chapterIndex];
    [chapterCacheDict setObject:object forKey:indexString];

    [chapterCacheDict enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
        NSInteger index = [(NSString *)key integerValue];
        if ((self.currentChapterIndex - index > 1 || index - self.currentChapterIndex > 1) && self.currentChapterIndex > 0) {
            [chapterCacheDict removeObjectForKey:key];
        }
    }];
    NSString *cachePath = [self getCachePath:chapterIndex isChapterModel:NO];
    [NSKeyedArchiver archiveRootObject:object toFile:cachePath];
}

- (void)cacheModelWithIndex:(NSInteger)chapterIndex withObject:(id)object
{
    [chapterModelCaches setObject:object forKey:[LDUtil toString:chapterIndex]];
    [chapterModelCaches enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
        NSInteger index = [(NSString *)key integerValue];
        if ((self.currentChapterIndex - index > 1 || index - self.currentChapterIndex > 1) && self.currentChapterIndex > 0) {
            [chapterModelCaches removeObjectForKey:key];
        }
    }];
    
    NSString *path = [self getCachePath:chapterIndex isChapterModel:YES];
    [NSKeyedArchiver archiveRootObject:object toFile:path];
}

- (void)cacheMarkBookModel:(LDBookModel *)bookModel
{
   
    if (!LDDataParserMD5STR) {
        LDDataParserMD5STR = [NSString stringWithFormat:@"%@/%@",bookModel.name,bookModel.author];
    }
    [self.markBookCacheDic setObject:self.markChapterArray forKey:[NSString stringWithFormat:@"%@",LDDataParserMD5STR]];
    
    [NSKeyedArchiver archiveRootObject:self.markBookCacheDic toFile:[self getMarkCachePath]];
}

- (void)forwardCacheIfNeed:(BOOL)isForward
{
    DLog(@"forwardCacheIfNeed currentChapterIndex == %zd",_currentChapterIndex);
    NSInteger predictIndex = isForward ? (self.currentChapterIndex + 1) : (self.currentChapterIndex - 1);
    if (predictIndex <= 0)
        return;
    dispatch_async(dispatch_get_global_queue(0, 0), ^() {
        NSMutableArray *nextPageArray = [self pageArrayFromCache:predictIndex];
        if (!nextPageArray || nextPageArray.count == 0) {
            DLog(@"forward cache needed! chapter: %ld", (long)predictIndex);
            [self requestChapterWithIndex:predictIndex];
        }else {
            DLog(@"no need forward cache");
        }
    });
}

- (void)forwardCacheWithChapterModel:(LDChapterModel *)chapterModel
{
    DLog(@"forward cache start! chapter: %ld", (long)chapterModel.chapterIndex);
    NSMutableArray *array = [NSMutableArray array];
    NSAttributedString *attrString = [self.dataParser attrbutedStringFromChapterModel:chapterModel configuration:self.configuration];
    if (!chapterModel.title || [chapterModel.title isEqualToString:@""]) {
        chapterModel.title = self.bookModel.name;
    }
//    [NSThread sleepForTimeInterval:8];
    [self cacheModelWithIndex:chapterModel.chapterIndex withObject:chapterModel];
    NSMutableArray* markChapterArray = [self getChapterMarkArrayWithChapterIndex:chapterModel.chapterIndex isDeleteChapterModelArray:NO];
    [self.dataParser cutPageWithAttributedString:attrString configuration:self.configuration  chapterIndex:chapterModel.chapterIndex andChapterMarkArray:markChapterArray completeProgress:^(NSInteger completedPageCounts, LDPageModel *page, BOOL completed) {
        [array addObject:page];
        if (completed) {
            [self cacheChapterWithIndex:chapterModel.chapterIndex withObject:array];
            DLog(@"forward cache end! chapter: %ld", (long)chapterModel.chapterIndex);
            [self successRequestPageArrayWithChapterModel:chapterModel andPageModel:array.lastObject];
            if (self.state == LDReaderBusy && !_isReCutChapter) {//保证预缓存刷新之前,再次重分页,引起闪一下的问题
                dispatch_async(dispatch_get_main_queue(), ^() {
                    [self postReaderStateNotification:LDReaderReady];
                    if (!self.tableView) {
                        [self loadPageViewController];
                        [self readPage:self.currentPageIndex];
                    }
                });
            }else{
                
            }
//            if (self.pageTurningByAuto) {
//                dispatch_async(dispatch_get_main_queue(), ^() {
//                    if (self.pageTurningByAuto == 1 && [self pageArrayFromCache:self.currentChapterIndex + 1]) {
//                        DLog(@"auto page turning by forward cache state...");
//                        [self postReaderStateNotification:LDReaderReady];
//                        [self nextPage];
//                        self.pageTurningByAuto = 0;
//                    }else if (self.pageTurningByAuto == -1 && [self pageArrayFromCache:self.currentChapterIndex - 1]) {
//                        DLog(@"auto page turning by forward cache state...");
//                        [self postReaderStateNotification:LDReaderReady];
//                        [self prePage];
//                        self.pageTurningByAuto = 0;
//                    }
//                });
//            }
        }
    }];
}

- (NSMutableArray *)pageArrayFromCache:(NSInteger)chapterIndex
{
    NSString *indexString = [LDUtil toString:chapterIndex];
    NSMutableArray *result = chapterCacheDict[indexString];
    if (!result || result.count == 0) {
        NSString *cachePath = [self getCachePath:chapterIndex isChapterModel:NO];
        result = [NSKeyedUnarchiver unarchiveObjectWithFile:cachePath];
    }
    if (!result) {
        DFLog(WARNING, @"chapter %d array is nil in cache", chapterIndex);
    }
    
    return result;
}

- (LDChapterModel *)chapterModelFromCache:(NSInteger)chapterIndex
{
    NSString *indexString = [LDUtil toString:chapterIndex];
    LDChapterModel *model = chapterModelCaches[indexString];
    if (!model) {
        NSString *path = [self getCachePath:chapterIndex isChapterModel:YES];
        model = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    }
    if (!model) {
        DFLog(WARNING, @"chapter model is nil in cache");
    }
    return model;
}

- (NSMutableArray *)getChapterMarkArrayWithChapterIndex:(NSInteger)chapterIndex isDeleteChapterModelArray:(BOOL)isDeleteChapterModelArray
{
    NSString *cachePath = [self getMarkCachePath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath isDirectory:NULL]) {
       self.markBookCacheDic = [NSKeyedUnarchiver unarchiveObjectWithFile:cachePath];
        NSMutableArray *markBookArray = [self.markBookCacheDic objectForKey:[NSString stringWithFormat:@"%@",LDDataParserMD5STR]];
        self.markChapterArray = markBookArray;
        __block NSMutableArray *markChapterArray;
        [markBookArray enumerateObjectsUsingBlock:^(NSMutableDictionary *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj objectForKey:@(chapterIndex)]) {
                markChapterArray = [obj objectForKey:@(chapterIndex)];
                if (isDeleteChapterModelArray) {
                    [self.markChapterArray removeObject:obj];
                }
            }
        }];
        return markChapterArray;
    }else{
        return nil;
    }
}

- (NSString *)getCachePath:(NSInteger)chapterIndex isChapterModel:(BOOL)isChapterModel
{
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *tmpPath = [NSString stringWithFormat:@"ldreader-black/%@/", self.bookModel.name];
    NSString *subName = isChapterModel == YES ? @"chapterModel" : @"chapterArray";
    NSString *cacheDir = [NSString stringWithFormat:@"%@/%@", tmpPath, subName];
    cacheDir = [documentPath stringByAppendingPathComponent:cacheDir];
    if (![[NSFileManager defaultManager] fileExistsAtPath:cacheDir isDirectory:NULL]) {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:&error];
        if (error && [self.delegate respondsToSelector:@selector(reader:failedWithError:)]) {
            DFLog(ERROR, @"reader io error");
            [self.delegate reader:self failedWithError:[NSError errorWithDomain:@"ldreader" code:-8000 userInfo:@{NSLocalizedFailureReasonErrorKey:@"reader inner io error"}]];
        }
    }
    NSString *subPath = [NSString stringWithFormat:@"chapter-%ld.res", (long)chapterIndex];
    NSString *cachePath = [cacheDir stringByAppendingPathComponent:subPath];
    return cachePath;
}

- (NSString *)getMarkCachePath{
    NSString *document = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *filePath = [document stringByAppendingPathComponent:[NSString stringWithFormat:@"%@",@"markCacheFile"]];
    DLog(@"markCachPath == %@",filePath);
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:NULL]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *cachePath = [filePath stringByAppendingPathComponent:@"markCacheDic.res"];
    return cachePath;
}


- (void)cleanChapterCache
{
    [chapterCacheDict removeAllObjects];
    [self.lastCommentViewHeightDic removeAllObjects];
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *tmpPath = [NSString stringWithFormat:@"ldreader-black/%@/", self.bookModel.name];
    NSString *subName = @"chapterArray";
    NSString *cacheDir = [NSString stringWithFormat:@"%@/%@", tmpPath, subName];
    cacheDir = [documentPath stringByAppendingPathComponent:cacheDir];
    
    NSArray *files = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:cacheDir error:nil];
    for (NSString *path in files) {
        DLog(@"clean: %@/%@", cacheDir, path);
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", cacheDir, path] error:nil];
    }
}

- (void)cleanReaderCacheIfNeed
{
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *readerPath = [documentPath stringByAppendingPathComponent:@"ldreader-black"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:readerPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:readerPath error:nil];
    }
    
}

- (void)deleteOldFilesWithCompletionBlock{
        NSString *document = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *storePath = [document stringByAppendingPathComponent:@"ldreader-books"];
        NSURL *diskCacheURL = [NSURL fileURLWithPath:storePath isDirectory:YES];
        //文件的属性列表:1.文件访问日期;2.是否是文件夹
        NSArray<NSString *> *resourceKeys = @[NSURLContentAccessDateKey,NSURLIsDirectoryKey];
        //该枚举器预先获取缓存文件的有用属性
        NSDirectoryEnumerator *fileEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:diskCacheURL
                                                   includingPropertiesForKeys:resourceKeys
                                                                      options:NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                                                 errorHandler:NULL];
        
        NSMutableDictionary<NSURL *, NSDictionary<NSString *, id> *> *cacheFiles = [NSMutableDictionary dictionary];
        NSUInteger currentCacheSize = 0;
        for (NSURL *fileURL in fileEnumerator) {
            NSError *error;
            NSDictionary<NSString *, id> *tmpResourceValues = [fileURL resourceValuesForKeys:resourceKeys error:&error];
            if (error || !tmpResourceValues || ![tmpResourceValues[NSURLIsDirectoryKey] boolValue]) {
                continue;
            }
            NSMutableDictionary *resourceValues = [NSMutableDictionary dictionaryWithDictionary:tmpResourceValues];
            cacheFiles[fileURL] = resourceValues;//获取文件夹下资源的属性
            NSUInteger directionaryCacheSize = [self directioryCacheSizeWithURL:fileURL];
            resourceValues[@"directionaryTotalSize"] = @(directionaryCacheSize);
            currentCacheSize += directionaryCacheSize;
        }
        // 内存超过最大允许内存大小,删除过期的文件
        // 若缓存文件的大小大于我们配置的最大大小,则执行基于文件大小的清理,首先删除最老的文件
        if (self.configuration.maxCacheSize > 0 && currentCacheSize > self.configuration.maxCacheSize) {
            // 以设置的最大缓存大小的一半作为清理目标
            const NSUInteger desiredCacheSize = self.configuration.maxCacheSize / 2;
            //排序最后访问时间的文件,由早到近
            //按照最后修改时间来排序剩下的缓存文件
            NSArray<NSURL *> *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                                     usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                         return [obj1[NSURLContentAccessDateKey] compare:obj2[NSURLContentAccessDateKey]];
                                                                     }];
            
                    for (NSURL *fileURL in sortedFiles) {
                        if ([[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil]) {
                                NSDictionary<NSString *, id> *resourceValues = cacheFiles[fileURL];
                                NSNumber *totalAllocatedSize = resourceValues[@"directionaryTotalSize"];
                                currentCacheSize -= totalAllocatedSize.unsignedIntegerValue;
                                if (currentCacheSize < desiredCacheSize) {
                                    break;
                                }
                            }
                    }
        }
}

- (NSUInteger)directioryCacheSizeWithURL:(NSURL *)directoryURL
{
    NSUInteger currentCacheSize = 0;
    NSArray<NSString *> *resourceKeys = @[NSURLTotalFileAllocatedSizeKey];
    NSDirectoryEnumerator *fileEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:directoryURL
                                                                 includingPropertiesForKeys:resourceKeys
                                                                                    options:NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                                                               errorHandler:NULL];
    
    for (NSURL *fileURL in fileEnumerator) {
        NSError *error;
        NSDictionary<NSString *, id> *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:&error];
        if (error || !resourceValues || [resourceValues[NSURLIsDirectoryKey] boolValue]) {
            continue;
        }
       currentCacheSize += [resourceValues[NSURLTotalFileAllocatedSizeKey] unsignedIntegerValue];
    }
    
    return currentCacheSize;
}


# pragma mark - UIPageViewControllerDelegate && UIPageViewControllerDataSource

//static BOOL willStepIntoNextChapter = NO;
- (nullable UIViewController *)pageViewController:(nonnull UIPageViewController *)pageViewController viewControllerAfterViewController:(nonnull UIViewController *)viewController {
    if (self.configuration.scrollType == LDReaderScrollPagingHorizontal && self.pageTurningByTap) {
        return nil;
    }
    return [self nextVCAfterViewController:viewController];
}

//static BOOL willStepIntoLastChapter = NO;
- (nullable UIViewController *)pageViewController:(nonnull UIPageViewController *)pageViewController viewControllerBeforeViewController:(nonnull UIViewController *)viewController {
    if (self.configuration.scrollType == LDReaderScrollPagingHorizontal && self.pageTurningByTap) {
        return nil;
    }
    return [self lastVCBeforeViewController:viewController];
}

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed
{
    
    DLog(@"didFinishAnimating or transitionCompleted");
    if (finished) {
        DLog(@"didFinishAnimating");
        self.view.userInteractionEnabled = YES;
        [self pageViewControllerDidFinishedTransition:pageViewController previousViewController:previousViewControllers.firstObject];
    }
    if (completed) {
        DLog(@"transitionCompleted");
//        [self pageViewControllerDidFinishedTransition:pageViewController previousViewController:previousViewControllers.firstObject];
    }
}


/**
 滑动手势翻页的时候调用,将要翻页的时候调用
 */
- (void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray<UIViewController *> *)pendingViewControllers
{
    DLog(@"willTransitionToViewControllers pageViewController == %@ pendingViewControllers == %@",pageViewController,pendingViewControllers);
    if (self.configuration.scrollType == LDReaderScrollPagingHorizontal) {
        BOOL flag = YES;
        if (pendingViewControllers) {
            LDPageViewController *page = pageViewController.viewControllers.firstObject;
            LDPageViewController *pendingPage = (LDPageViewController *)pendingViewControllers.firstObject;
            flag = (pendingPage.index < page.index || pendingPage.chapterBelong < page.chapterBelong) ? NO : YES;
        }
        if (flag && self.currentPageIndex == [self pageArrayFromCache:self.currentChapterIndex].count - 1) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(reader:failedWithError:)]) {
                [self.delegate reader:self failedWithError:[NSError errorWithDomain:@"ldreader" code:-8004 userInfo:@{NSLocalizedFailureReasonErrorKey:@"arrived last page."}]];
            }
        }
        if (self.configuration.backgroundImage) {
            ((LDPageViewController *)pendingViewControllers.firstObject).backgroundImageView.image = self.configuration.backgroundImage;
        }else {
            ((LDPageViewController *)pendingViewControllers.firstObject).backgroundImageView = nil;
            ((LDPageViewController *)pendingViewControllers.firstObject).view.backgroundColor = self.configuration.backgroundColor;
        }
    }else{
        self.view.userInteractionEnabled = NO;
    }
}

/*
 * 为了实现和点击翻页代码复用，pageViewController的上述三个回调实现代码全部抽离出来
 * 下一页的VC
 */
- (nullable UIViewController *)nextVCAfterViewController:(nonnull UIViewController *)viewController
{
    DLog(@"page turning forward");
    //滑动翻页
    NSArray *pages = [self pageArrayFromCache:self.currentChapterIndex];
    if (self.configuration.scrollType == LDReaderScrollPagingHorizontal) {
        LDPageViewController *page = (LDPageViewController *)viewController;
        NSInteger nextIndex = page.index + 1;
        DLog(@"nextVCAfterViewController page.index == %zd",page.index);
//        NSLog(@"nextIndex == %zd pages.count == %zd,currentChapterIndex == %zd",nextIndex,pages.count,_currentChapterIndex);
//#warning error
        if (nextIndex == pages.count) {
          
            [self requestChapterWithIndex:self.currentChapterIndex + 1];
            UIViewController *vc = [self getPageVCWithIndex:0 inChapter:self.currentChapterIndex + 1];
            if (!vc && [_chapterCacheFlags objectForKey:@(self.currentChapterIndex + 1)]) {//数据尚未缓存完毕，通知外部进入忙碌状态
                DFLog(WARNING, @"chapter is caching. @%s", __FUNCTION__);
//                if (self.pageTurningByTap) {
//                    [self postReaderStateNotification:LDReaderBusy];
////                    self.pageTurningByAuto = 1;
//                }else {
//                    UIScrollView *scroll = [self getScrollViewFromPageVC];
//                    scroll.tag = 900;
//                }
//                if (!self.pageTurningByTap) {
                    self.pageHunger = YES;
//                }
                [self postReaderStateNotification:LDReaderBusy];
            }
            return vc;
        }
        return [self getPageVCWithIndex:nextIndex];
    }
    //仿真翻页
    if (self.currentPageIndex == [self pageArrayFromCache:self.currentChapterIndex].count - 1) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(reader:failedWithError:)]) {
            [self.delegate reader:self failedWithError:[NSError errorWithDomain:@"ldreader" code:-8004 userInfo:@{NSLocalizedFailureReasonErrorKey:@"arrived last page."}]];
        }
    }
    static BOOL arriveLastPage = NO;
    NSInteger nextIndex;
    if ([viewController isKindOfClass:[LDPageViewController class]]) {
        LDPageViewController *page = (LDPageViewController *)viewController;
        nextIndex = page.index + 1;
        if (nextIndex == pages.count) {
            arriveLastPage = YES;
        }
        LDBackViewController *backVC = [[LDBackViewController alloc] init];
        [backVC grabViewController:page];
        return backVC;
    }
    if (arriveLastPage) {
       
        [self requestChapterWithIndex:self.currentChapterIndex + 1];
        arriveLastPage = NO;
        UIViewController *vc = [self getPageVCWithIndex:0 inChapter:self.currentChapterIndex + 1];
        if (!vc && [_chapterCacheFlags objectForKey:@(self.currentChapterIndex + 1)]) {//数据尚未缓存完毕，通知外部进入忙碌状态
            DFLog(WARNING, @"chapter is caching. @%s", __FUNCTION__);
            [self postReaderStateNotification:LDReaderBusy];
//            self.pageTurningByAuto = 1;
        }
        return vc;
    }
    LDBackViewController *page = (LDBackViewController *)viewController;
    return [self getPageVCWithIndex:page.index + 1 inChapter:page.chapterBelong];

}

//获取上一页的VC
- (nullable UIViewController *)lastVCBeforeViewController:(nonnull UIViewController *)viewController
{
    //滑动翻页
    DFLog(INFO, @"page turning backword");
    if (self.configuration.scrollType == LDReaderScrollPagingHorizontal) {
        LDPageViewController *page = (LDPageViewController *)viewController;
        NSInteger nextIndex = page.index - 1;
        if (nextIndex < 0) {
            if (self.currentChapterIndex - 1 <= 0)
                return nil;
           
            [self requestChapterWithIndex:self.currentChapterIndex - 1];
            NSInteger count = [self pageArrayFromCache:self.currentChapterIndex - 1].count;
            if (count == 0) {
                self.pageHunger = YES;
                [self postReaderStateNotification:LDReaderBusy];
                return nil;
            }
            UIViewController *vc = [self getPageVCWithIndex:count + nextIndex inChapter:self.currentChapterIndex - 1];
            if (!vc && [_chapterCacheFlags objectForKey:@(self.currentChapterIndex - 1)]) {//数据尚未缓存完毕，通知外部进入忙碌状态
                DFLog(WARNING, @"chapter is caching. @%s", __FUNCTION__);
//                if (self.pageTurningByTap) {
//                    [self postReaderStateNotification:LDReaderBusy];
////                    self.pageTurningByAuto = -1;
//                }else {
//                    UIScrollView *scroll = [self getScrollViewFromPageVC];
//                    scroll.tag = 901;
//                }
//                if (!self.pageTurningByTap) {
                    self.pageHunger = YES;
//                }
                [self postReaderStateNotification:LDReaderBusy];
            }
            return vc;
        }
        return [self getPageVCWithIndex:nextIndex];
    }
    //仿真翻页
    if (self.currentPageIndex == 0 && self.currentChapterIndex == 1) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(reader:failedWithError:)]) {
            [self.delegate reader:self failedWithError:[NSError errorWithDomain:@"ldreader" code:-8003 userInfo:@{NSLocalizedFailureReasonErrorKey:@"arrived first page."}]];
        }
    }
    static BOOL arriveFirstPage = NO;
    if ([viewController isKindOfClass:[LDPageViewController class]]) {
        LDBackViewController *backVC = [[LDBackViewController alloc] init];
        LDPageViewController *page = (LDPageViewController *)viewController;
        NSInteger nextIndex = page.index - 1;
        if (nextIndex < 0) {
            if (self.currentChapterIndex - 1 <= 0)
                return nil;
            arriveFirstPage = YES;
            
            [self requestChapterWithIndex:self.currentChapterIndex - 1];
            nextIndex = [self pageArrayFromCache:self.currentChapterIndex - 1].count - 1;

            LDPageViewController *vc = [self getPageVCWithIndex:nextIndex inChapter:self.currentChapterIndex - 1];
            if (!vc && [_chapterCacheFlags objectForKey:@(self.currentChapterIndex - 1)]) {//数据尚未缓存完毕，通知外部进入忙碌状态
                DFLog(WARNING, @"chapter is caching. @%s", __FUNCTION__);
                [self postReaderStateNotification:LDReaderBusy];
//                self.pageTurningByAuto = -1;
                backVC = nil;
            }else {
                [backVC grabViewController:vc];
            }
            return backVC;
        }
        
        [backVC grabViewController:[self getPageVCWithIndex:nextIndex inChapter:page.chapterBelong]];
        return backVC;
    }
    
    LDBackViewController *page = (LDBackViewController *)viewController;
    if (arriveFirstPage) {
        arriveFirstPage = NO;
        return [self getPageVCWithIndex:page.index inChapter:self.currentChapterIndex - 1];
    }
    return [self getPageVCWithIndex:page.index inChapter:page.chapterBelong];
}


/**
  完成翻页时的回调
 */
- (void)pageViewControllerDidFinishedTransition:(UIPageViewController *)pageViewController previousViewController:(UIViewController *)viewController
{
    DLog(@"page finished transition");
    self.startLocationPreviousPage = -1;
    LDPageViewController *page = pageViewController.viewControllers.firstObject;
    LDPageViewController *previousPage = (LDPageViewController *)viewController;

    _currentPageIndex = page.index;
    
    DLog(@"current page chapterBelong：%ld, previous page chapterBelong: %ld, currrntChapterIndex == %zd", (long)page.chapterBelong, previousPage.chapterBelong,_currentChapterIndex);
    
    self.currentChapterIndex = page.chapterBelong;
    NSArray *curPages = [self pageArrayFromCache:self.currentChapterIndex];
    
    LDPageModel *pageModel = curPages[_currentPageIndex];
    if ([self.delegate respondsToSelector:@selector(reader:progressWithChapter:pageCounts:pageIndex: currentWordIndex:)]) {
        [self.delegate reader:self progressWithChapter:self.currentChapterIndex pageCounts:curPages.count pageIndex:self.currentPageIndex + 1 currentWordIndex:pageModel.range.location];
    }
    
    if (!self.pageTurningByTap && [self.delegate respondsToSelector:@selector(reader:currentPageWithPageString:)]) {
        //非水平翻页点击翻页模式下回调
        for (UIView *view in page.view.subviews) {
            if ([view isKindOfClass:[LDAttributedLabel class]]) {
                self.currentAttributeLabel = (LDAttributedLabel *)view;
                break;
            }
        }
        [self.delegate reader:self currentPageWithPageString:[self.currentAttributeLabel.attributedString string]];
    }
    
//    DLog(@"willStepIntoLastChapter: %@", willStepIntoLastChapter?@"YES":@"NO");
//    DLog(@"willStepIntoNextChapter: %@", willStepIntoNextChapter?@"YES":@"NO");
//    DLog(@"current chapter：%ld, total pages：%ld, current page：%ld", (long)self.currentChapterIndex, (long)curPages.count, (long)_currentPageIndex);
}


#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]] && self.configuration.scrollType == LDReaderScrollCurl) {
        return NO;
    }
    return YES;
}

#pragma mark - UITableViewDelegate && UITableViewDataSource
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.tableViewDataArray.count;
}


-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.tableView.tempCellIndex = indexPath.row;
    DLog(@"测试当前cellIndex == %zd",indexPath.row);
    static NSString *const identifier = @"DTAttributedTextCell";
    LDReaderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    __weak typeof(self) weakSelf = self;
    if (!cell) {
        cell = [[LDReaderTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier andConfiguration:self.configuration];
        cell.text_label.edgeInsets = UIEdgeInsetsMake(0, _configuration.contentFrame.origin.x,0, _configuration.contentFrame.origin.x);
        cell.text_label.readerView = self.view;
    }
    
    [cell.text_label setCanNotShowMenuBlock:^{
    if(weakSelf.configuration.scrollType == LDReaderScrollVertical && [weakSelf.delegate respondsToSelector:@selector(reader:failedWithError:)]){
        [weakSelf.delegate reader:weakSelf failedWithError:[NSError errorWithDomain:@"ldreader" code:-8001 userInfo:@{NSLocalizedFailureReasonErrorKey:@"该模式不支持长按选择"}]];
         }
    }];
    LDPageModel *pageModel = self.tableViewDataArray[indexPath.row];
    if (self.menuTitles.count) {
        cell.text_label.menuTitles = self.menuTitles;
        [cell.text_label setMenuItemClockClick:^(NSString *title, NSString *contentStr, NSRange range) {
            [weakSelf menuItemDidClickWithTitle:title andSelectedRange:range andPageModel:pageModel];
            if ([weakSelf.delegate respondsToSelector:@selector(reader:menuItemClickWithTitle:andContentString: andSelectedRange:)]) {
                [weakSelf.delegate reader:weakSelf menuItemClickWithTitle:title andContentString:contentStr andSelectedRange:range];
            }
        }];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    [cell setPageModel:pageModel config:self.configuration];
    
    // 添加广告
    if (pageModel.advertising) {
        if (cell.advertisingView) {
            [cell.advertisingView removeFromSuperview];
            cell.advertisingView = nil;
        }
        cell.contentView.ld_height = self.tableView.ld_height;
        cell.contentView.ld_width = self.tableView.ld_width;
        cell.text_label.frame = cell.contentView.bounds;
        UIView *advertisingView = [self getAdvertisingView:cell.text_label chapterIndex:pageModel.chapterIndex andPageIndex:pageModel.pageIndex];
        [cell.text_label addSubview:advertisingView];
        cell.advertisingView = advertisingView;
    }else{
        [cell.advertisingView removeFromSuperview];
        cell.advertisingView = nil;
    }
    
    if (pageModel.lastPage) {
        if (cell.tailView) {
            [cell.tailView removeFromSuperview];
            cell.tailView = nil;
        }
        cell.contentView.ld_height = self.tableView.ld_height;
        cell.contentView.ld_width = self.tableView.ld_width;
        cell.text_label.frame = cell.contentView.bounds;
        UIView *tailView = [self getChapterTailView:cell.text_label chapterIndex:pageModel.chapterIndex];
        if (_configuration.scrollType == LDReaderScrollVertical) {
            [self.lastCommentViewHeightDic setObject:@(CGRectGetMaxY(tailView.frame)) forKey:@(pageModel.chapterIndex)];
        }
        cell.tailView = tailView;
        [cell.text_label addSubview:tailView];
    }else{
        [cell.tailView removeFromSuperview];
        cell.tailView = nil;
    }
    if ([self.delegate respondsToSelector:@selector(reader:currentPageWithPageString:)]) {
        self.currentAttributeLabel = cell.text_label;
        [self.delegate reader:self currentPageWithPageString:[cell.text_label.attributedString string]];
    }
    return cell;
}


-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self lastPageCellHeightWithIndexPath:indexPath];
}



-(void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    //注:isRecute属性当进行重分页时为YES,如:改变行间距
    if (self.tableView.isReCute){
        if (self.tableView.isLastPage) {
            self.tableView.tableViewScrollDirection = LDTableViewScrollDirectionTop;
            [self requestNextChapterWithCellIndex:_currentPageIndex];
        }
        if (self.tableView.isFirstPage) {
            self.tableView.tableViewScrollDirection = LDTableViewScrollDirectionBottom;
        [self requestPreChapterWithCellIndexPath:_currentPageIndex];
        }
        self.tableView.isReloadTableView = NO;
        self.tableView.scrollEnabled = YES;
        self.tableView.isReCute = NO;
        self.tableView.isLastPage = NO;
        self.tableView.isFirstPage = NO;
        return;
    }
    //注:当进行全局刷新,或者竖向模式互相切换时为YES
    if (self.tableView.isReloadTableView){
        self.tableView.isReloadTableView = NO;
        self.tableView.scrollEnabled = YES;
        return;
    }
    self.view.userInteractionEnabled = YES;
    //注:当重分页或者翻页模式切换时展示页面偏移量改变时为YES
    if (self.tableView.isRemoved) {
        self.tableView.isRemoved = NO;
        return;
    }
    
    if (self.manualJumpChapterOrPage)
        return;

    CGFloat preContentOffsetY = _currentCellIndex*self.tableView.ld_height;
    if (preContentOffsetY == self.tableView.contentOffset.y && self .configuration.scrollType == LDReaderScrollPagingVertical) {
        return;
    }
    if (indexPath.row == self.tableView.preEndCellIndex) return;
    
    //注意:异常处理,防止滑动非常快导致滑到最顶端后又重新回调该代理方法
    if (self.tableView.contentOffset.y == 0 && self.tableView.isHandleExceptional ) return;
    
    NSIndexPath *currentCellIndexPath;
        switch (self.tableView.tableViewScrollDirection) {
            case LDTableViewScrollDirectionTop:
                if(_currentCellIndex == self.tableView.tempCellIndex){
                    _currentCellIndex += 1;
                }else{
                    _currentCellIndex = self.tableView.tempCellIndex;
                }
                break;
            case LDTableViewScrollDirectionBottom:
                if (_currentCellIndex == self.tableView.tempCellIndex) {
                    _currentCellIndex -= 1;
                }else{
                    _currentCellIndex = self.tableView.tempCellIndex;
                }
                break;
            default:
                break;
        }
        
        currentCellIndexPath = [NSIndexPath indexPathForRow:_currentCellIndex inSection:0];
    if (currentCellIndexPath.row > indexPath.row) {//向上滑且保证滑过去了
        self.startLocationPreviousPage = -1;
        self.tableView.tableViewScrollDirection = LDTableViewScrollDirectionTop;
        //设置页码
        if (_currentPageIndex+1 >= [[self getCurrentChapterPageArray] count]) {//换章
            self.currentPageIndex = 0;
            self.currentChapterIndex = _currentChapterIndex +1;
        }else{//未换章
            LDPageModel *pageModel = self.tableViewDataArray[_currentCellIndex];
            self.currentPageIndex = pageModel.pageIndex;
//            NSLog(@"self.CurrentChapterIndex3");
            self.currentChapterIndex = pageModel.chapterIndex;
//            DLog(@"向下换页 currentChapterIndex == %zd,currentPageIndex == %zd",_currentChapterIndex,self.currentPageIndex);
        }
        self.statusBarView.currentPageIndex = self.currentPageIndex;
        self.statusBarView.pageCounts = [[self getCurrentChapterPageArray] count];
        [self setChapterTitle];
        
        //请求数据
//
        if (currentCellIndexPath.row+1 == self.tableViewDataArray.count  && self.currentPageIndex +1 == [[self getCurrentChapterPageArray] count]) {//滑到tableView最后一页
            [self requestNextChapterWithCellIndex:currentCellIndexPath.row];
        }
    }else if(currentCellIndexPath.row < indexPath.row  ){      //向下滑
        self.startLocationPreviousPage = -1;
        self.tableView.tableViewScrollDirection = LDTableViewScrollDirectionBottom;
        //设置页码
        if(self.currentPageIndex <= 0 && self.currentChapterIndex > 1){//向下换章
//            NSLog(@"self.CurrentChapterIndex4");
            self.currentChapterIndex = _currentChapterIndex - 1;
            self.currentPageIndex = [[self getCurrentChapterPageArray] count] -1;
//            DLog(@"向上换章 currentChapterIndex == %zd",_currentChapterIndex);
        }else{//换页
            LDPageModel *pageModel = self.tableViewDataArray[_currentCellIndex];
            self.currentPageIndex = pageModel.pageIndex;
            self.currentChapterIndex = pageModel.chapterIndex;
        }
        self.statusBarView.pageCounts = [[self getCurrentChapterPageArray] count];
        self.statusBarView.currentPageIndex = self.currentPageIndex;
        [self setChapterTitle];
        //请求数据
        if (currentCellIndexPath.row == 0 && _currentChapterIndex > 1) {//滑到当前章节的第一页
            [self requestPreChapterWithCellIndexPath:currentCellIndexPath.row];
        }
    }
    LDPageModel *pageModel = self.tableViewDataArray[_currentCellIndex];
    if ([self.delegate respondsToSelector:@selector(reader:progressWithChapter:pageCounts:pageIndex: currentWordIndex:)]) {
#warning pageArrayFromCache需要修改
        [self.delegate reader:self progressWithChapter:self.currentChapterIndex pageCounts:[self pageArrayFromCache:self.currentChapterIndex].count pageIndex:self.currentPageIndex+1 currentWordIndex:pageModel.range.location];
    }
    self.tableView.preEndCellIndex = indexPath.row;
    [self handleTheExceptionalCase];
}


#pragma mark - tableView数据处理
//根据当前章节获取包括上下两个章节的所有数据
-(void)getAllTableViewDatasWithReloadIndex:(NSInteger)reloadIndex
{
    self.tableView.preDatasCount =self.tableViewDataArray.count;
    if(reloadIndex == 1){
        [self.tableViewDataArray addObjectsFromArray:[self getNextChapterPageArray]];
         NSInteger tmpIndex = self.tableView.preDatasCount;
        NSMutableArray *tmpArray = [NSMutableArray array];
        for (int i = 0; i<self.tableViewDataArray.count - self.tableView.preDatasCount; i++) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:tmpIndex+i inSection:0];
            [tmpArray addObject:indexPath];
        }
        [self insertTableViewWithReloadIndex:1 andTmpArray:tmpArray];
    }else if (reloadIndex == -1){
        // 控制数据源
        NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:
                               NSMakeRange(0,[[self getPreChapterPageArray] count])];
        [self.tableViewDataArray insertObjects:[self getPreChapterPageArray] atIndexes:indexes];
        [self insertTableViewWithReloadIndex:reloadIndex andTmpArray:NULL];
    }
    
    
    
}

//  更新数据源并刷新
- (void) insertTableViewWithReloadIndex:(NSInteger)reloadIndex andTmpArray:(NSArray *)tmpArray
{
   
    
    if(reloadIndex == 1){//拼接下一章
        DLog(@"局部刷新");
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView beginUpdates];
            [self.tableView insertRowsAtIndexPaths:tmpArray withRowAnimation:UITableViewRowAnimationNone];
            [self.tableView endUpdates];
            [self postReaderStateNotification:LDReaderReady];
        });
    }else{//拼接上一章
        DLog(@"全局刷新");
        self.tableView.scrollEnabled = NO;
        self.tableView.isReloadTableView = YES;
        [self.tableView reloadData];
    }
    
    //设置偏移量
    dispatch_async(dispatch_get_main_queue(), ^{
        if(reloadIndex == -1){
            NSInteger preChapterIndex = _currentChapterIndex - 1;
            CGFloat addOffsetY = [self addOffsetWithPreChapterIndex:preChapterIndex];
            _currentCellIndex = [[self getPreChapterPageArray] count] + _currentPageIndex;
            if (self.configuration.scrollType == LDReaderScrollVertical) {
                [self.tableView setContentOffset:CGPointMake(0, _currentCellIndex*self.tableView.ld_height+addOffsetY) animated:NO];
            }else{
                [self.tableView setContentOffset:CGPointMake(0, _currentCellIndex*self.tableView.ld_height) animated:NO];
            }
            if(self.state == LDReaderBusy) [self postReaderStateNotification:LDReaderReady];
            
        }
    });
}


-(NSArray *)getPreChapterPageArray
{
    return [self pageArrayFromCache:_currentChapterIndex-1];
}

-(NSArray *)getCurrentChapterPageArray
{
   return [self pageArrayFromCache:_currentChapterIndex];
}

-(NSArray *)getNextChapterPageArray
{
    return [self pageArrayFromCache:_currentChapterIndex+1];
}

/**
 请求上一章
 */
-(void)requestPreChapterWithCellIndexPath:(NSInteger)currentCellIndex
{
//    DLog(@"requestPreChapterWithCellIndexPath ");
    if (self.currentChapterIndex - 1 <= 0) return;
    //拼接数据源
    if ([[self getPreChapterPageArray] count]) {
//        DLog(@"刷新");
        [self reloadTableViewWithReloadIndex:-1];
    }else{
//        DLog(@"请求上一章==");
        self.tableView.isRequestPreChaper = YES;
        [self requestChapterWithIndex:self.currentChapterIndex - 1];
    }
}

//请求下一章
- (void)requestNextChapterWithCellIndex:(NSInteger)currentCellIndex
{
//    DLog(@"requestNextChapterWithCellIndex ");
    //拼接数据源
    if ([[self getNextChapterPageArray] count]) {
        [self reloadTableViewWithReloadIndex:1];
    }else{
//        DLog(@"无缓存,请求下一章 chapterIndex == %zd",self.currentChapterIndex + 1);
        self.tableView.isRequestNextChaper = YES;
        [self requestChapterWithIndex:self.currentChapterIndex + 1];
    }
}

- (void)handleTheExceptionalCase
{
    switch (self.tableView.tableViewScrollDirection) {
        case LDTableViewScrollDirectionTop:
            if (self.tableView.contentOffset.y == self.tableView.contentSize.height - self.tableView.ld_height) {
                if (self.currentPageIndex+1<[[self getCurrentChapterPageArray] count]) {
                    self.tableView.isHandleExceptional = YES;
                    _currentCellIndex = self.tableViewDataArray.count -1;
                    //处理滑动太快,连续几个不调用didenddisplay
                    LDPageModel *pageModel = self.tableViewDataArray.lastObject;
//                    NSLog(@"self.CurrentChapterIndex6");
                    self.currentChapterIndex = pageModel.chapterIndex;
                    self.currentPageIndex = [[self getCurrentChapterPageArray] count] -1;
                    
                    
                    self.statusBarView.currentPageIndex = _currentPageIndex;
                    self.statusBarView.pageCounts = [[self getCurrentChapterPageArray] count];

                    DLog(@"LDTableViewScrollDirectionTop 异常处理currentChapterIndex == %zd",_currentChapterIndex);
                    
                    [self requestNextChapterWithCellIndex:_currentCellIndex];
                }
            }
            break;
        case LDTableViewScrollDirectionBottom:
            if (self.tableView.contentOffset.y == 0) {
                if (self.currentPageIndex>0) {
                    self.tableView.isHandleExceptional = YES;
                    self.currentPageIndex = 0;
                    _currentCellIndex = 0;
                    self.statusBarView.currentPageIndex = _currentPageIndex;
                    //处理滑动太快,连续几个不调用didenddisplay
                    LDPageModel *pageModel = self.tableViewDataArray[0];
                    
                    self.currentChapterIndex = pageModel.chapterIndex;
//                    NSLog(@"self.CurrentChapterIndex7 == %zd",_currentChapterIndex);
                    self.statusBarView.pageCounts = [[self getCurrentChapterPageArray] count];
                    DLog(@"LDTableViewScrollDirectionBottom 异常处理 currentChapterIndex == %zd",_currentChapterIndex);
                    [self requestPreChapterWithCellIndexPath:_currentCellIndex];
                }
            }
            break;
    }
}


-(void)preCalculationChapterPageWithPageModel:(LDPageModel *)pageModel
{
    dispatch_async(dispatch_get_main_queue(), ^{
        LDAttributedLabel *contentView =[[LDAttributedLabel alloc]initWithFrame:self.configuration.contentFrame andConfiguration:self.configuration];
        contentView.attributedString = [pageModel.attrString convertToAttributedString:self.configuration];
        UIView *tailView = [self getChapterTailView:contentView chapterIndex:pageModel.chapterIndex];
        [self.lastCommentViewHeightDic setObject:@(CGRectGetMaxY(tailView.frame)) forKey:@(pageModel.chapterIndex)];
//        [self.lastCommentViewHeightDic setObject:@(tailView.ld_y) forKey:[NSString stringWithFormat:@"tailY%zd",pageModel.chapterIndex]];
    });
}


#pragma mark -标注
- (void)menuItemDidClickWithTitle:(NSString *)title andSelectedRange:(NSRange)range andPageModel:(LDPageModel *)pageModel
{
    if ([title isEqualToString:@"标注"]) {
        NSMutableArray *chapterMarkArr = [self getChapterMarkArrayWithChapterIndex:_currentChapterIndex isDeleteChapterModelArray:YES];
        if (chapterMarkArr) {
            [self addChapterMarkArray:chapterMarkArr andRange:range];
        }else{
            chapterMarkArr = [NSMutableArray array];
            [chapterMarkArr addObject:[NSValue valueWithRange:range]];
        }
        [self.markChapterArray addObject:@{@(_currentChapterIndex) : chapterMarkArr}];
        //        [pageModel.markArray addObject:[NSValue valueWithRange:range]];
        NSMutableArray *pageArray = [NSMutableArray arrayWithArray:[self pageArrayFromCache:_currentChapterIndex]];
        [pageArray replaceObjectAtIndex:pageModel.pageIndex withObject:pageModel];
        [self cacheChapterWithIndex:_currentChapterIndex withObject:pageArray];
        [self cacheMarkBookModel:self.bookModel];
    }
}

- (void)addChapterMarkArray:(NSMutableArray *)chapterMarkarray andRange:(NSRange)range 
{
    __block BOOL isNewRange = NO;
    [chapterMarkarray enumerateObjectsUsingBlock:^(NSValue *rangeValue, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange oldRange = rangeValue.rangeValue;
        if (range.location + range.length > oldRange.location && range.location +range.length <= oldRange.location+oldRange.length) {
            [chapterMarkarray removeObject:rangeValue];
            [chapterMarkarray addObject:[NSValue valueWithRange:range]];
            isNewRange = NO;
            *stop = YES;
        }else if (range.location >= oldRange.location && range.location < oldRange.location + oldRange.length){
            [chapterMarkarray removeObject:rangeValue];
            [chapterMarkarray addObject:[NSValue valueWithRange:range]];
            isNewRange = NO;
            *stop = YES;
        }else if (range.location <= oldRange.location && range.location+range.length >= oldRange.location+oldRange.length){
            [chapterMarkarray removeObject:rangeValue];
            [chapterMarkarray addObject:[NSValue valueWithRange:range]];
            isNewRange = NO;
            *stop = YES;
        }else{
            isNewRange = YES;
        }
    }];
    if (isNewRange) {
        [chapterMarkarray addObject:[NSValue valueWithRange:range]];
    }
}

#pragma mark -tableViewRowheight
- (CGFloat)lastPageCellHeightWithIndexPath:(NSIndexPath *)indexPath
{
    LDPageModel *pageModel = self.tableViewDataArray[indexPath.row];
    if (self.configuration.scrollType == LDReaderScrollVertical && pageModel.lastPage) {
        CGFloat tailViewMaxY = [[self.lastCommentViewHeightDic objectForKey:@(pageModel.chapterIndex)] floatValue];
        return tailViewMaxY > self.tableView.ld_height?tailViewMaxY:self.tableView.ld_height;
    }else{
        return self.tableView.ld_height;
    }
}

#pragma mark -UIScrollViewDelegate
static CGPoint scrollOriginOffset;
-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    scrollOriginOffset = scrollView.contentOffset;
    if (self.configuration.scrollType == LDReaderScrollPagingVertical || self.configuration.scrollType == LDReaderScrollVertical) {
        CGPoint translatePoint = [scrollView.panGestureRecognizer translationInView:scrollView.superview];
        [self handleTheExceptionalCase];
        if (scrollView.contentOffset.y == 0 && translatePoint.y >=0) {//向下滑动
            DLog(@"scrollViewWillBeginDragging 向上");
            if (self.currentPageIndex == 0 && self.currentChapterIndex == 1) {
                if (self.delegate && [self.delegate respondsToSelector:@selector(reader:failedWithError:)]) {
                    [self.delegate reader:self failedWithError:[NSError errorWithDomain:@"ldreader" code:-8003 userInfo:@{NSLocalizedFailureReasonErrorKey:@"arrived first page."}]];
                    isCallback = YES;
                }
            }
            [self updateReaderStateWithIsNext:NO];
        }else if (scrollView.contentOffset.y == (scrollView.contentSize.height - self.tableView.ld_height) && translatePoint.y < 0){//向上滑
            if(self.configuration.scrollType == LDReaderScrollVertical &&
               self.tableView.contentOffset.y == (self.tableView.contentSize.height - self.tableView.ld_height)){//到达底部
                if (self.delegate && [self.delegate respondsToSelector:@selector(reader:failedWithError:)]
                    ) {
                    [self.delegate reader:self failedWithError:[NSError errorWithDomain:@"ldreader" code:-8004 userInfo:@{NSLocalizedFailureReasonErrorKey:@"arrived last page."}]];
                    isCallback = YES;
                }
            }
            [self updateReaderStateWithIsNext:YES];
        }
    }
}

static BOOL isCallback = NO;
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (self.configuration.scrollType == LDReaderScrollPagingHorizontal) {
        if (scrollView.contentOffset.x - self.configuration.contentFrame.size.width < 0 && !isCallback) {
            if (self.currentPageIndex == 0 && self.currentChapterIndex == 1) {
                if (self.delegate && [self.delegate respondsToSelector:@selector(reader:failedWithError:)]) {
                    [self.delegate reader:self failedWithError:[NSError errorWithDomain:@"ldreader" code:-8003 userInfo:@{NSLocalizedFailureReasonErrorKey:@"arrived first page."}]];
                    isCallback = YES;
                }
            }
        }
        if (scrollView.contentOffset.x > scrollOriginOffset.x &&
            ![_chapterCacheFlags objectForKey:@(self.currentChapterIndex + 1)] &&
            !isCallback) {
            if (self.currentPageIndex == [self pageArrayFromCache:self.currentChapterIndex].count - 1) {
                if (self.delegate && [self.delegate respondsToSelector:@selector(reader:failedWithError:)]) {
                    [self.delegate reader:self failedWithError:[NSError errorWithDomain:@"ldreader" code:-8004 userInfo:@{NSLocalizedFailureReasonErrorKey:@"arrived last page."}]];
                    isCallback = YES;
                }
            }
        }
    }
    
//    if (scrollView.tag) {
//        DLog(@"--- scrollViewDidScroll origin offset %f, current offset %f, tag %d",scrollOriginOffset, scrollView.contentOffset.x, scrollView.tag);
//        CGFloat currentOffset = scrollView.contentOffset.x;
//        if (scrollOriginOffset && currentOffset > scrollOriginOffset && scrollView.tag == 900) {
////                    [self loadPageViewController];
////                    [self readPage:self.currentPageIndex];
//            [self postReaderStateNotification:LDReaderBusy];
////            self.pageTurningByAuto = 1;
//            scrollView.tag = 0;
//        }else if (scrollOriginOffset && currentOffset < scrollOriginOffset && scrollView.tag == 901) {
//            [self postReaderStateNotification:LDReaderBusy];
////            self.pageTurningByAuto = -1;
//            scrollView.tag = 0;
//        }
//        scrollOriginOffset = 0;
//    }
    if (self.tableView) {
        if (scrollView.contentOffset.y < 0 && !isCallback) {
            if (self.currentPageIndex == 0 && self.currentChapterIndex == 1) {
                if (self.delegate && [self.delegate respondsToSelector:@selector(reader:failedWithError:)]) {
                    [self.delegate reader:self failedWithError:[NSError errorWithDomain:@"ldreader" code:-8003 userInfo:@{NSLocalizedFailureReasonErrorKey:@"arrived first page."}]];
                    isCallback = YES;
                }
            }
        }
        
        self.tableView.isHandleExceptional = NO;
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    isCallback = NO;
}


#pragma mark - systemMethod
- (BOOL)prefersStatusBarHidden
{
    return YES;
}

-(void)dealloc
{
    [self.observeKeyPaths enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self.configuration removeObserver:self forKeyPath:obj context:nil];
    }];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    //clean cache
    [self cleanReaderCacheIfNeed];
    LDDataParserMD5STR = nil;
    DLog(@"ldreader distroyed");
}


-(void)didReceiveMemoryWarning
{
}

@end
