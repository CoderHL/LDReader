//
//  ViewController.m
//  LDTxtReaderDemo
//
//  Created by 刘洪 on 2017/10/11.
//  Copyright © 2017年 刘洪. All rights reserved.
//

#import "ViewController.h"
#import <LDReader/LDReader.h>
#import "UIView+LDExtension.h"
#import "UIImage+WF.h"
#import "LXDBacktraceLogger.h"
#import "LXDAppFluecyMonitor.h"
#import "NSString+YJHTML.h"



@interface ViewController ()<LDReaderDelegate, UITableViewDelegate, UITableViewDataSource,UIGestureRecognizerDelegate>
{
//    BOOL _isSettingMode;
    UIButton *_settingModeBtn;
}

@property (nonatomic, strong) UIView *settingView;
@property (nonatomic, weak) UIButton *preBtn;
@property (nonatomic, weak) LDReader *readerVC;
@property (nonatomic, strong) LDConfiguration *configuration;
@property (nonatomic, strong) UITableView *bookList;
@property (nonatomic, strong) NSMutableArray *settingBtnArray;
@property (nonatomic, strong) UIActivityIndicatorView *indicatorView;

@property (nonatomic, strong) NSArray *bookArray;
@property (nonatomic, strong) NSArray *authorArray;
@property (nonatomic, strong) NSArray *coverArray;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segment;
@property (nonatomic, weak) UIViewController *mvc;
@property (nonatomic, strong) NSArray *chapterTable;

@property (nonatomic, weak) UITableView *jumpChapterTableView;
@property (nonatomic, weak) UIView *jumpChapterView;

@property (nonatomic, strong) NSArray *currentPageparagraphs;

@end

#define KScreenHeight [UIScreen mainScreen].bounds.size.height
#define KScreenWidth [UIScreen mainScreen].bounds.size.width
#define UserDefaultObjectForKey(_KEY_)  [[NSUserDefaults standardUserDefaults] objectForKey:_KEY_]
#define UserDefaultSetObjectForKey(_OBJECT_, _KEY_) [[NSUserDefaults standardUserDefaults] setObject:_OBJECT_ forKey:_KEY_]

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self execDemoExtraProcessing];
    self.view.backgroundColor = [UIColor whiteColor];
    self.bookArray = @[@"桃源杂论", @"神雕侠侣", @"缘起郭襄", @"笑傲江湖"];
    self.authorArray = @[@"世外高人", @"金庸", @"斗酒僧", @"金庸宝宝"];
    UIImage *cover1 = [UIImage imageNamed:@"cover1.jpg"];
    UIImage *cover2 = [UIImage imageNamed:@"cover2.jpg"];
    UIImage *cover3 = [UIImage imageNamed:@"cover3.jpg"];
    UIImage *cover4 = [UIImage imageNamed:@"cover4.jpg"];
    self.coverArray = @[cover1, cover2, cover3, cover4];
    
    [self.segment addTarget:self action:@selector(segmentDidClicked:) forControlEvents:UIControlEventValueChanged];
    self.segment.selectedSegmentIndex = UserDefaultObjectForKey(@"ld_scrollType")?[UserDefaultObjectForKey(@"ld_scrollType") integerValue] : 1;
    [[LXDAppFluecyMonitor sharedMonitor] startMonitoring];
}

- (void)segmentDidClicked:(UISegmentedControl *)seg
{
    switch (seg.selectedSegmentIndex) {
        case 0:
            self.configuration.scrollType = LDReaderScrollCurl;
            break;
        case 1:
            self.configuration.scrollType = LDReaderScrollPagingHorizontal;
            break;
        case 2:
            self.configuration.scrollType = LDReaderScrollPagingVertical;
            break;
        case 3:
            self.configuration.scrollType = LDReaderScrollVertical;
            break;
        default:
            break;
    }
}

- (LDConfiguration *)configuration
{
    if (!_configuration) {
        _configuration = [LDConfiguration shareConfiguration];
        _configuration.commentEntryEnable = NO;
        _configuration.scrollType = UserDefaultObjectForKey(@"ld_scrollType")?[UserDefaultObjectForKey(@"ld_scrollType") integerValue]:LDReaderScrollPagingHorizontal;
        _configuration.hasCover = YES;
    }
    return _configuration;
}

-(NSMutableArray *)settingBtnArray
{
    if (!_settingBtnArray) {
        _settingBtnArray = [NSMutableArray array];
    }
    return _settingBtnArray;
}

- (IBAction)begainBtnClick:(id)sender {
    
    self.bookList = [[UITableView alloc] initWithFrame:CGRectMake(10, 20 + 64, self.view.ld_width - 20, self.view.ld_height - 20 - 64) style:UITableViewStylePlain];
    self.bookList.dataSource = self;
    self.bookList.delegate = self;
    
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.frame = self.view.frame;
    vc.view.backgroundColor = [UIColor whiteColor];
    [vc.view addSubview:self.bookList];
    self.mvc = vc;
    
    UINavigationBar *bar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 20, self.view.ld_width, 64)];
    UIBarButtonItem *leftBtn = [[UIBarButtonItem alloc] initWithTitle:@"返回" style:UIBarButtonItemStylePlain target:self action:@selector(onBackClicked)];
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:@"我的书架"];
    item.leftBarButtonItem = leftBtn;
    [bar pushNavigationItem:item animated:YES];
    [vc.view addSubview:bar];
    
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)onBackClicked
{
    [self.mvc dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - tableview delegate

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewCell *cell;
    if (tableView == self.bookList) {
        cell = [tableView dequeueReusableCellWithIdentifier:@"book.cell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"book.cell"];
        }
        for (UIView *view in cell.contentView.subviews) {
            [view removeFromSuperview];
        }
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(100, 0, cell.contentView.ld_width - 110, 120)];
        label.text = self.bookArray[indexPath.row % 4];
        label.textColor = [UIColor blackColor];
        [cell.contentView addSubview:label];
        
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 10, 80, 120 - 20)];
        imageView.image = self.coverArray[indexPath.row % 4];
        [cell.contentView addSubview:imageView];
        
        cell.backgroundColor = (indexPath.row % 2 != 0)?[UIColor whiteColor]:[UIColor lightGrayColor];
    }else{
        cell = [tableView dequeueReusableCellWithIdentifier:@"jumpChapter"];
        if (!cell) {
            cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"jumpChapter"];
        }
        cell.textLabel.text = [NSString stringWithFormat:@"第 %zd 章",indexPath.row+1];
    }
    
    return cell;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.bookList) {
        return 10;
    }else{
        return self.chapterTable.count;
    }
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == self.bookList) {
        return 120;
    }else{
        return 44;
    }
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == self.bookList) {
        //调起阅读器
        [self openBookAtIndexPath:indexPath];
    }else{
        [self jumpChapterWithChapterIndex:indexPath.row+1];
    }
}

-(void)jumpChapterWithChapterIndex:(NSInteger)chapterIndex
{
        LDChapterModel *chapter = [LDChapterModel new];
        chapter.chapterIndex = chapterIndex;
    
        //chapter.commentCounts = 888; // 该评论数将显示在页面底部
        __block NSMutableString *path;
        __block NSString *title;
        [self.chapterTable enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
            NSDictionary *dict = (NSDictionary *)obj;
            if ([dict[@"index"] intValue] == chapterIndex) {
                path = dict[@"path"];
                title = dict[@"title"];
                *stop = YES;
            }
        }];
        if (path) {
            chapter.path = path;
            chapter.title = title;
            self.readerVC.manualJumpChapterOrPage = YES;
            [self.readerVC readWithChapter:chapter pageIndex:1]; //章节和页码最小从1开始
        }
}

#pragma mark - LDReader Delegate

- (void)reader:(LDReader *)reader needChapterWithIndex:(NSInteger)chapterIndex
{
    LDChapterModel *nextChapter = [LDChapterModel new];
    nextChapter.chapterIndex = chapterIndex;
    switch (chapterIndex) {
        case 1:
            nextChapter.commentCounts = 88;
            nextChapter.path = [self chapterPathForBookName:reader.bookModel.name chapterIndex:chapterIndex];
            break;
        case 2:
            nextChapter.commentCounts = 100;
            nextChapter.path = [self chapterPathForBookName:reader.bookModel.name chapterIndex:chapterIndex];
            break;
        case 3:
            nextChapter.commentCounts = 724;
            nextChapter.path = [self chapterPathForBookName:reader.bookModel.name chapterIndex:chapterIndex];
            break;
        case 4:
            nextChapter.commentCounts = 666;
            nextChapter.path = [self chapterPathForBookName:reader.bookModel.name chapterIndex:chapterIndex];
            break;
        case 5:
            nextChapter.commentCounts = 593;
            nextChapter.path = [self chapterPathForBookName:reader.bookModel.name chapterIndex:chapterIndex];
            break;
        default:
            //没有此章节
//            nextChapter = nil;
            break;
    }
    
    [reader readWithChapter:nextChapter pageIndex:1];
}

-(void)readerDidClickSettingFrame:(LDReader *)reader
{
    NSLog(@"调用设置界面");
    NSArray *titles = @[@"font +",@"font -",@"linespace +",@"linespace -",@"Curl",@"PagingHorizontal",@"PagingVertical",@"Vertical",@"theme1",@"theme2",@"theme3",@"esc",@"Simplified Conversion",@"jumpChapter",@"Test"];
    [self creatSettingViewWithTitles:titles];
    
    [[UIApplication sharedApplication].keyWindow addSubview:self.settingView];
    
    self.settingView.hidden = NO;
}

- (void)readerDidClickChapterComment:(LDReader *)reader
{
    NSLog(@"进入章节评论页面");
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"进入社区" message:@"" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
    [alert show];
}

- (void)reader:(LDReader *)reader chapterTailView:(UIView *)tailView chapterIndex:(NSInteger)chapterIndex
{
    NSLog(@"请求章节末尾评论视图");
//    tailView.layer.borderColor = [UIColor blackColor].CGColor;
//    tailView.layer.borderWidth = 1.0;
//    if (reader.configuration.scrollType == LDReaderScrollVertical) {
//        tailView.ld_height = 500;
//    }
//    if (tailView.ld_height > 20) {
//        UILabel *label = [UILabel new];
//        label.text = [NSString stringWithFormat:@"章节末尾评论区高度为%.0lf",tailView.ld_height];
//        label.textAlignment = NSTextAlignmentCenter;
//        label.center = CGPointMake(tailView.ld_width/2, tailView.ld_height/2);
//        label.bounds = CGRectMake(0, 0, tailView.ld_width-2, tailView.ld_height-2);
//        [tailView addSubview:label];
//    }
}


- (void)reader:(LDReader *)reader failedWithError:(NSError *)error {
    NSLog(@"发生错误");
    if (error.code == -8001) {
//        @"该模式不支持长按选择"
        UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:nil message:[error.userInfo objectForKey:NSLocalizedFailureReasonErrorKey] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alertView show];
    }
    if (error.code == -8002) {
        NSLog(@"文本编码错误");
    }
    if (error.code == -8003) {
        NSLog(@"到达第一页了。。");
    }
    if (error.code == -8004) {
        NSLog(@"到达当前章节最后一页。。");
        /*
        if(当前章节为最后一章) {
            NSLog(@"到达最后一页了。。");
         }
         */
    }
}

//pageIndex 从1开始
- (void)reader:(LDReader *)reader progressWithChapter:(NSInteger)chapterIndex pageCounts:(NSInteger)pageCounts pageIndex:(NSInteger)pageIndex currentWordIndex:(NSInteger)currentWordIndex {
    NSLog(@"阅读进度: 第%ld页 | 当前章节：%ld, 总页数: %ld页, 当前页第一个字的索引:%zd", (long)pageIndex, (long)chapterIndex, (long)pageCounts,currentWordIndex);
}

- (void)reader:(LDReader *)reader currentPageWithPageString:(NSString *)currentPageString
{
    NSArray *paragraphs = [currentPageString componentsSeparatedByString:@"\n"];
    self.currentPageparagraphs = paragraphs;
    self.configuration.autoSelectedParagraphColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:0.5];
//    NSLog(@"currentPageString == %@",currentPageString);
//    self.readerVC.selectedParagraphIndex = 0;
}


- (void)reader:(LDReader *)reader readerStateChanged:(LDReaderState)state
{
    switch (state) {
        case LDReaderBusy:
            NSLog(@"阅读器忙碌中...");
            [self.readerVC.view addSubview:self.indicatorView];
            [self.indicatorView startAnimating];
            break;
        case LDReaderReady:
            NSLog(@"阅读器已就绪...");
            [self.indicatorView stopAnimating];
            [self.indicatorView removeFromSuperview];
            
            break;
        default:
            break;
    }
}

- (void)reader:(LDReader *)reader chapterTable:(NSArray *)chapterTable
{
    NSLog(@"获得该书切分后的所有章节信息");
    /*
     chapterTable为字典数组，包含了解析后的所有章节的目录以及路径信息，元素结构示例如下：
     @{
        @"index":章节序号,
        @"title":章节标题,
        @"path":章节路径
     }
     */
    self.chapterTable = chapterTable;
    
    NSLog(@"self.chapterTable == %@",self.chapterTable);
    
}

-(void)reader:(LDReader *)reader menuItemClickWithTitle:(NSString *)title andContentString:(NSString *)contentStr andSelectedRange:(NSRange)range
{
    UIAlertController *alertC = [UIAlertController alertControllerWithTitle:title message:contentStr preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
    [alertC addAction:action];
    [reader presentViewController:alertC animated:YES completion:nil];
    //    UIAlertView *alertV = [[UIAlertView alloc]initWithTitle:title message:contentStr delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
    //    [alertV show];
}

-(void)reader:(LDReader *)reader currentChapterWithPages:(NSArray *)pages currentChapterIndex:(NSInteger)chapterIndex
{
    //返回当前章节的每一页的内容
//    NSLog(@"currentChapterWithPages  pages == %@,count == %zd, chapterIndex == %zd",pages.firstObject,pages.count,chapterIndex);
}

-(void)reader:(LDReader *)reader advertisingView:(UIView *)advertisingView chapterIndex:(NSInteger)chapterIndex andPageIndex:(NSInteger)pageIndex
{
    NSLog(@"advertisingView chapterIndex == %zd, PageIndex == %zd",chapterIndex,pageIndex);
    UIImageView *imageView= [[UIImageView alloc]initWithFrame:(CGRect){.origin=CGPointMake(0, 0),.size=CGSizeMake(advertisingView.ld_width, advertisingView.ld_height)}];
    if(chapterIndex == 1){
        imageView.image = [UIImage imageNamed:@"advertising"];
    }else{
        imageView.image = [UIImage imageNamed:@"advertising2"];
    }
    
    imageView.userInteractionEnabled = YES;
    UITapGestureRecognizer *advertisingTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(advertisingTap)];
    [imageView addGestureRecognizer:advertisingTap];
    [advertisingView addSubview:imageView];
}

- (void)advertisingTap
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.baidu.com"]];
}


#pragma mark - other logic

- (void)openBookAtIndexPath:(NSIndexPath *)indexPath
{
    
    self.configuration.fontSize = UserDefaultObjectForKey(@"ld_fontSize")?[UserDefaultObjectForKey(@"ld_fontSize") floatValue] : 15;
    self.configuration.lineSpacing = UserDefaultObjectForKey(@"ld_lineSpacing")?[UserDefaultObjectForKey(@"ld_lineSpacing") floatValue] : 10;
    self.configuration.hasCover = YES;
    self.configuration.advertisingIndex = 1;
    switch ([UserDefaultObjectForKey(@"ld_theme") integerValue]) {
        case 1:
            self.configuration.backgroundImage = [UIImage imageNamed:@"oldBook.jpg"];
            break;
        case 2:
            self.configuration.backgroundColor = [UIColor whiteColor];
            break;
        default:
            self.configuration.backgroundImage = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"water_mode_bg" ofType:@"png"]];
            break;
    }
    self.configuration.backgroundColor = [UIColor whiteColor];
    LDReader *reader = [LDReader new];
    self.readerVC = reader;
    reader.delegate = self;
    reader.configuration = self.configuration;
    reader.menuTitles = @[@"复制",@"剪切",@"标注",@"分享",@"笔记",@"吐槽",@"社区",@"评价",@"划线",@"高亮",@"撤销更改"];
    reader.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
    [self.mvc presentViewController:reader animated:YES completion:nil];
    
    LDBookModel *bookModel = [[LDBookModel alloc] init];
    bookModel.name = self.bookArray[indexPath.row % 4];
    bookModel.author = self.authorArray[indexPath.row % 4];
    bookModel.coverImage = self.coverArray[indexPath.row % 4];
    reader.bookModel = bookModel;
    
    if (indexPath.row % 4 == 3) {
        //整本阅读
        NSString *bookPath = [[NSBundle mainBundle] pathForResource:@"笑傲江湖" ofType:@"txt"];
        [reader readWithFilePath:bookPath andChapterIndex:1 pageIndex:1];
    }else {
        //分章节阅读
        LDChapterModel *chapter = [LDChapterModel new];
        chapter.chapterIndex = 1;
//        chapter.commentCounts = 888; // 该评论数将显示在页面底部
//        chapter.path = [self chapterPathForBookName:bookModel.name chapterIndex:1];
        chapter.contentString = [[self htmlStr] stringByConvertingHTMLToPlainText];
        [reader readWithChapter:chapter pageIndex:1]; //章节和页码最小从1开始
    }
}

- (NSString *)chapterPathForBookName:(NSString *)name chapterIndex:(NSInteger)chapterIndex
{
    NSString *path;
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *bookDir = [documentPath stringByAppendingPathComponent:@"demo-HJK-Books"];
    if ([name isEqualToString:@"神雕侠侣"]) {
        path = [bookDir stringByAppendingPathComponent:[NSString stringWithFormat:@"chapter%ld.txt", (long)chapterIndex]];
    }if ([name isEqualToString:@"缘起郭襄"]) {
        path = [bookDir stringByAppendingPathComponent:[NSString stringWithFormat:@"chapter~%ld.txt", (long)chapterIndex]];
    }if ([name isEqualToString:@"桃源杂论"]) {
        path = [bookDir stringByAppendingPathComponent:[NSString stringWithFormat:@"chapter-%ld.txt", (long)chapterIndex]];
    }
    
    return path;
}

-(void)creatSettingViewWithTitles:(NSArray *)settings
{       UIView *settingView ;
    if (!_settingView) {
        settingView = [[UIView alloc]initWithFrame:CGRectMake(0, 0  , KScreenWidth, KScreenHeight)];
        settingView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
        _settingView = settingView;
        UIView *btnsView = [[UIView alloc]initWithFrame:CGRectMake(0, KScreenHeight/2, KScreenWidth, KScreenHeight/2)];
        btnsView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:.5];
        [settingView addSubview:btnsView];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(hidenSettingView:)];
        [settingView addGestureRecognizer:tap];
        
        [settings enumerateObjectsUsingBlock:^(id  _Nonnull title, NSUInteger idx, BOOL * _Nonnull stop) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
            
            btn.tag = 10+idx;
            switch (btn.tag) {
                case 10:
                case 11:
                case 12:
                case 13:
                    [self.settingBtnArray addObject:btn];
                    break;
                default:
                    break;
            }
            [btn setTitle:title forState:UIControlStateNormal];
            [btn setBackgroundColor:[UIColor whiteColor]];
            [btn addTarget:self action:@selector(settingBtnClick:) forControlEvents:UIControlEventTouchUpInside];
            btn.contentEdgeInsets = UIEdgeInsetsMake(0, 5, 0, 5);
            [btn sizeToFit];
            btn.ld_height = 60;
            [self setUpbtnFrameWithBtn:btn];
            [btnsView addSubview:btn];
        }];
    }
}

- (void)createJumpChapterTableView
{
    if (!_jumpChapterTableView) {
        UITableView *jumpChapterTableView = [[UITableView alloc]initWithFrame:CGRectMake(-0.4*KScreenWidth, 0, 0.4*KScreenWidth, KScreenHeight) style:UITableViewStylePlain];
        jumpChapterTableView.delegate = self;
        jumpChapterTableView.dataSource = self;
        self.jumpChapterTableView = jumpChapterTableView;
        UIView *tempView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, KScreenWidth, KScreenHeight)];
        self.jumpChapterView = tempView;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(hideJumpChapterTableView:)];
        tap.delegate = self;
        [tempView addGestureRecognizer:tap];
        tempView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
        [tempView addSubview:jumpChapterTableView];
        [[UIApplication sharedApplication].keyWindow addSubview:tempView];
    }
    self.jumpChapterView.hidden = NO;
    [UIView animateWithDuration:.5 animations:^{
        self.jumpChapterTableView.ld_x = 0;
        
    }];
}

-(void)setUpbtnFrameWithBtn:(UIButton *)btn
{
    static CGFloat col_x = 10;
    static CGFloat len_y = 10;
    static NSInteger rows = 0;
    static BOOL isNewLine = NO;
    if (self.preBtn &&
        CGRectGetMaxX(self.preBtn.frame) + 10 + btn.ld_width
        > KScreenWidth)
    {
        rows += 1;
        isNewLine = YES;
    }else{
        isNewLine = NO;
    }
    
    btn.ld_y = len_y+(btn.ld_height + len_y)*rows;
    
    if (self.preBtn && isNewLine == NO) {
        
        btn.ld_x = CGRectGetMaxX(self.preBtn.frame) + col_x;
        
    }else{
        
        btn.ld_x = col_x;
        
    }
    
//    NSLog(@"btn.frame == %@",NSStringFromCGRect(btn.frame));
    
    self.preBtn = btn;
    
}

-(void)settingBtnClick:(UIButton *)btn
{
    switch (btn.tag) {
        case 10:
        {
            self.configuration.fontSize++;
            UIButton *tmpBtn = self.settingBtnArray[1];
            tmpBtn.enabled = YES;
            if (self.configuration.fontSize >= 25){
                btn.enabled = NO;
            }
            UserDefaultSetObjectForKey(@(self.configuration.fontSize), @"ld_fontSize");
        }
            break;
        case 11:
        {
            self.configuration.fontSize--;
           UIButton * tmpBtn = self.settingBtnArray[0];
            tmpBtn.enabled = YES;
            if (self.configuration.fontSize <= 10){
                btn.enabled = NO;
            }
            UserDefaultSetObjectForKey(@(self.configuration.fontSize), @"ld_fontSize");
        }
           
            break;
            
        case 12:
        {
            self.configuration.lineSpacing += 1;
            UIButton *tmpBtn = self.settingBtnArray[3];
            tmpBtn.enabled = YES;
//            if (self.configuration.lineSpacing >= 3) {
//                btn.enabled = NO;
//            }
            UserDefaultSetObjectForKey(@(self.configuration.lineSpacing), @"ld_lineSpacing");
        }
            break;
        case 13:
        {
            self.configuration.lineSpacing -= 1;
            UIButton *tempBtn = self.settingBtnArray[2];
            tempBtn.enabled = YES;
//            if (self.configuration.lineSpacing <= 1.6) {
//                btn.enabled = NO;
//            }
            UserDefaultSetObjectForKey(@(self.configuration.lineSpacing), @"ld_lineSpacing");
        }
            break;
        case 14:
            self.configuration.scrollType = LDReaderScrollCurl;
            UserDefaultSetObjectForKey(@(LDReaderScrollCurl), @"ld_scrollType");
            self.segment.selectedSegmentIndex = 0;
            break;
        case 15:
            self.configuration.scrollType = LDReaderScrollPagingHorizontal;
            UserDefaultSetObjectForKey(@(LDReaderScrollPagingHorizontal), @"ld_scrollType");
            self.segment.selectedSegmentIndex = 1;
            break;
        case 16:
            self.configuration.scrollType = LDReaderScrollPagingVertical;
            UserDefaultSetObjectForKey(@(LDReaderScrollPagingVertical), @"ld_scrollType");
            self.segment.selectedSegmentIndex = 2;
            break;
        case 17:
            self.configuration.scrollType = LDReaderScrollVertical;
            UserDefaultSetObjectForKey(@(LDReaderScrollVertical), @"ld_scrollType");
            self.segment.selectedSegmentIndex = 3;
            break;
        case 18:
            NSLog(@"切换主题1");
            self.configuration.backgroundImage = [UIImage imageNamed:@"oldBook.jpg"];
            UserDefaultSetObjectForKey(@1, @"ld_theme");
            break;
        
        case 19:
            NSLog(@"切换主题2");
#warning 注意:阅读器内部同时设置多个阅读器设置,需要通过configuration来进行设置
            if(self.configuration.textColor == [UIColor blackColor]){
                [self.readerVC resettingReaderConfigurationWithDictionary:@{LDTextColor:[UIColor whiteColor],LDBackgroundImage:[UIImage imageWithColor:[UIColor blackColor]]}];
            }else{
                [self.readerVC resettingReaderConfigurationWithDictionary:@{LDTextColor:[UIColor blackColor],LDBackgroundImage:[UIImage imageWithColor:[UIColor whiteColor]]}];
            }
            UserDefaultSetObjectForKey(@2, @"ld_theme");
            break;
        case 20:
            self.configuration.backgroundImage = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"water_mode_bg" ofType:@"png"]];
            UserDefaultSetObjectForKey(@3, @"ld_theme");
            break;
        case 21:
            
            [self.mvc dismissViewControllerAnimated:YES completion:nil];
            self.settingView.hidden = YES;
            self.chapterTable = NULL;
            [self.jumpChapterTableView removeFromSuperview];
            break;
        case 22:
            self.configuration.isSimple = !self.configuration.isSimple;
            break;
        case 23:
            //注意:这是整本书的跳章操作
            if (self.chapterTable.count) {
                self.settingView.hidden = YES;
                [self createJumpChapterTableView];
            }
            break;
        case 24:
            {
                
                self.readerVC.manualJumpChapterOrPage = YES;
                LDChapterModel *chapter = [LDChapterModel new];
                chapter.chapterIndex = 1;
                //        chapter.commentCounts = 888; // 该评论数将显示在页面底部
                chapter.path = [self chapterPathForBookName:self.readerVC.bookModel.name chapterIndex:1];
                [self.readerVC readWithChapter:chapter pageIndex:2];
                
//                self.configuration.advertisingIndex = 0;
            }
            break;
        default:
            
            break;
    }
    
}

-(void)hidenSettingView:(UITapGestureRecognizer *)tap
{
    BOOL shouldCloseSettingView = YES;
    CGPoint point = [tap locationInView:tap.view];
    CGPoint locatePoint = CGPointMake(point.x, point.y - KScreenHeight * 0.5);
    UIView *btnsView = tap.view.subviews.firstObject;
    for (UIView *view in btnsView.subviews) {
        if (CGRectContainsPoint(view.frame, locatePoint)) {
            shouldCloseSettingView = NO;
            break;
        }
    }
    
    if (shouldCloseSettingView) {
        self.settingView.hidden = YES;
    }
}

-(void)hideJumpChapterTableView:(UITapGestureRecognizer *)tap{
        [UIView animateWithDuration:.5 animations:^{
            self.jumpChapterTableView.ld_x = -0.4*KScreenWidth;
        } completion:^(BOOL finished) {
            self.jumpChapterView.hidden = YES;
        }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)dealloc
{
    self.settingView = nil;
}

- (void)execDemoExtraProcessing
{
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *bookDir = [documentPath stringByAppendingPathComponent:@"demo-HJK-Books"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:bookDir]) {
        [[NSFileManager defaultManager] removeItemAtPath:bookDir error:nil];
    }
    [[NSFileManager defaultManager] createDirectoryAtPath:bookDir withIntermediateDirectories:YES attributes:nil error:nil];
    for (int i = 1; i <= 5; i++) {
        NSString *sourcePath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"chapter%d", i] ofType:@"txt"];
        NSString *destPath = [bookDir stringByAppendingPathComponent:[NSString stringWithFormat:@"chapter%d.txt", i]];
        [[NSFileManager defaultManager] copyItemAtPath:sourcePath toPath:destPath error:nil];
        sourcePath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"chapter-%d", i] ofType:@"txt"];
        destPath = [bookDir stringByAppendingPathComponent:[NSString stringWithFormat:@"chapter-%d.txt", i]];
        [[NSFileManager defaultManager] copyItemAtPath:sourcePath toPath:destPath error:nil];
        sourcePath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"chapter~%d", i] ofType:@"txt"];
        destPath = [bookDir stringByAppendingPathComponent:[NSString stringWithFormat:@"chapter~%d.txt", i]];
        [[NSFileManager defaultManager] copyItemAtPath:sourcePath toPath:destPath error:nil];
    }
}

-(UIActivityIndicatorView *)indicatorView
{
    if (!_indicatorView) {
        UIActivityIndicatorView *indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _indicatorView = indicatorView;
        
        _indicatorView.center = CGPointMake(0.5*self.view.bounds.size.width, 0.5*self.view.bounds.size.height);
        
        _indicatorView.hidesWhenStopped = YES;
    }
    return _indicatorView;
    
}

#pragma mark - UIGeaturreDelegate
-(BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.view == self.jumpChapterView) {
        if ([gestureRecognizer locationInView:gestureRecognizer.view].x>0.4*KScreenWidth) {
            return YES;
        }else{
            return NO;
        }
    }else{
        return YES;
    }
}




/*
 * 直接传入的章节文本
 */
static NSString *textConteStr = @"她喜欢喝银耳莲子羹，而且必须是上好的银耳，用小火慢慢炖到黏稠。那一日，他去看她，她冷冷地从屋里走出来，丢给他一本书，对他说：“厨房里小锅炖着东西，你帮我去看看。”他真真地守了一个多小时，端到她面前。他开着奔驰带她去山上农庄吃饭，回来的时候她在车上睡着。他送她回家，然后轻手轻脚抱她上楼，呵护如珍宝。他笑着对她说：“我知道你的心里藏着一团火。”他曾经有一个深爱的女友，她说“我现在还不能嫁给你，我想去欧洲”。有野心的女子，总是有很多资本的，也总是以为不怕丢弃。她走后，他换女人如换衣服。然后他遇到了她，天雷地火，甘愿用一个多小时为她等一锅羹。大家都认为这是一对璧人，家世相当，学历相当，男生待女生若公主。最后，却恰恰是因为家长之间的矛盾而分手。到了如今，她却笑着对我说：“这些故事，我已记不太清楚了，你怎么还记得？”\n她喜欢喝银耳莲子羹，而且必须是上好的银耳，用小火慢慢炖到黏稠。那一日，他去看她，她冷冷地从屋里走出来，丢给他一本书，对他说：“厨房里小锅炖着东西，你帮我去看看。”他真真地守了一个多小时，端到她面前。他开着奔驰带她去山上农庄吃饭，回来的时候她在车上睡着。他送她回家，然后轻手轻脚抱她上楼，呵护如珍宝。他笑着对她说：“我知道你的心里藏着一团火。”他曾经有一个深爱的女友，她说“我现在还不能嫁给你，我想去欧洲”。有野心的女子，总是有很多资本的，也总是以为不怕丢弃。她走后，他换女人如换衣服。然后他遇到了她，天雷地火，甘愿用一个多小时为她等一锅羹。大家都认为这是一对璧人，家世相当，学历相当，男生待女生若公主。最后，却恰恰是因为家长之间的矛盾而分手。到了如今，她却笑着对我说：“这些故事，我已记不太清楚了，你怎么还记得？”\n她喜欢喝银耳莲子羹，而且必须是上好的银耳，用小火慢慢炖到黏稠。那一日，他去看她，她冷冷地从屋里走出来，丢给他一本书，对他说：“厨房里小锅炖着东西，你帮我去看看。”他真真地守了一个多小时，端到她面前。他开着奔驰带她去山上农庄吃饭，回来的时候她在车上睡着。他送她回家，然后轻手轻脚抱她上楼，呵护如珍宝。他笑着对她说：“我知道你的心里藏着一团火。”他曾经有一个深爱的女友，她说“我现在还不能嫁给你，我想去欧洲”。有野心的女子，总是有很多资本的，也总是以为不怕丢弃。她走后，他换女人如换衣服。然后他遇到了她，天雷地火，甘愿用一个多小时为她等一锅羹。大家都认为这是一对璧人，家世相当，学历相当，男生待女生若公主。最后，却恰恰是因为家长之间的矛盾而分手。到了如今，她却笑着对我说：“这些故事，我已记不太清楚了，你怎么还记得？”\n她喜欢喝银耳莲子羹，而且必须是上好的银耳，用小火慢慢炖到黏稠。那一日，他去看她，她冷冷地从屋里走出来，丢给他一本书，对他说：“厨房里小锅炖着东西，你帮我去看看。”他真真地守了一个多小时，端到她面前。他开着奔驰带她去山上农庄吃饭，回来的时候她在车上睡着。他送她回家，然后轻手轻脚抱她上楼，呵护如珍宝。他笑着对她说：“我知道你的心里藏着一团火。”他曾经有一个深爱的女友，她说“我现在还不能嫁给你，我想去欧洲”。有野心的女子，总是有很多资本的，也总是以为不怕丢弃。她走后，他换女人如换衣服。然后他遇到了她，天雷地火，甘愿用一个多小时为她等一锅羹。大家都认为这是一对璧人，家世相当，学历相当，男生待女生若公主。最后，却恰恰是因为家长之间的矛盾而分手。到了如今，她却笑着对我说：“这些故事，我已记不太清楚了，你怎么还记得？”\n她喜欢喝银耳莲子羹，而且必须是上好的银耳，用小火慢慢炖到黏稠。那一日，他去看她，她冷冷地从屋里走出来，丢给他一本书，对他说：“厨房里小锅炖着东西，你帮我去看看。”他真真地守了一个多小时，端到她面前。他开着奔驰带她去山上农庄吃饭，回来的时候她在车上睡着。他送她回家，然后轻手轻脚抱她上楼，呵护如珍宝。他笑着对她说：“我知道你的心里藏着一团火。”他曾经有一个深爱的女友，她说“我现在还不能嫁给你，我想去欧洲”。有野心的女子，总是有很多资本的，也总是以为不怕丢弃。她走后，他换女人如换衣服。然后他遇到了她，天雷地火，甘愿用一个多小时为她等一锅羹。大家都认为这是一对璧人，家世相当，学历相当，男生待女生若公主。最后，却恰恰是因为家长之间的矛盾而分手。到了如今，她却笑着对我说：“这些故事，我已记不太清楚了，你怎么还记得？”\n她喜欢喝银耳莲子羹，而且必须是上好的银耳，用小火慢慢炖到黏稠。那一日，他去看她，她冷冷地从屋里走出来，丢给他一本书，对他说：“厨房里小锅炖着东西，你帮我去看看。”他真真地守了一个多小时，端到她面前。他开着奔驰带她去山上农庄吃饭，回来的时候她在车上睡着。他送她回家，然后轻手轻脚抱她上楼，呵护如珍宝。他笑着对她说：“我知道你的心里藏着一团火。”他曾经有一个深爱的女友，她说“我现在还不能嫁给你，我想去欧洲”。有野心的女子，总是有很多资本的，也总是以为不怕丢弃。她走后，他换女人如换衣服。然后他遇到了她，天雷地火，甘愿用一个多小时为她等一锅羹。大家都认为这是一对璧人，家世相当，学历相当，男生待女生若公主。最后，却恰恰是因为家长之间的矛盾而分手。到了如今，她却笑着对我说：“这些故事，我已记不太清楚了，你怎么还记得？”\n她喜欢喝银耳莲子羹，而且必须是上好的银耳，用小火慢慢炖到黏稠。那一日，他去看她，她冷冷地从屋里走出来，丢给他一本书，对他说：“厨房里小锅炖着东西，你帮我去看看。”他真真地守了一个多小时，端到她面前。他开着奔驰带她去山上农庄吃饭，回来的时候她在车上睡着。他送她回家，然后轻手轻脚抱她上楼，呵护如珍宝。他笑着对她说：“我知道你的心里藏着一团火。”他曾经有一个深爱的女友，她说“我现在还不能嫁给你，我想去欧洲”。有野心的女子，总是有很多资本的，也总是以为不怕丢弃。她走后，他换女人如换衣服。然后他遇到了她，天雷地火，甘愿用一个多小时为她等一锅羹。大家都认为这是一对璧人，家世相当，学历相当，男生待女生若公主。最后，却恰恰是因为家长之间的矛盾而分手。到了如今，她却笑着对我说：“这些故事，我已记不太清楚了，你怎么还记得？”\n她喜欢喝银耳莲子羹，而且必须是上好的银耳，用小火慢慢炖到黏稠。那一日，他去看她，她冷冷地从屋里走出来，丢给他一本书，对他说：“厨房里小锅炖着东西，你帮我去看看。”他真真地守了一个多小时，端到她面前。他开着奔驰带她去山上农庄吃饭，回来的时候她在车上睡着。他送她回家，然后轻手轻脚抱她上楼，呵护如珍宝。他笑着对她说：“我知道你的心里藏着一团火。”他曾经有一个深爱的女友，她说“我现在还不能嫁给你，我想去欧洲”。有野心的女子，总是有很多资本的，也总是以为不怕丢弃。她走后，他换女人如换衣服。然后他遇到了她，天雷地火，甘愿用一个多小时为她等一锅羹。大家都认为这是一对璧人，家世相当，学历相当，男生待女生若公主。最后，却恰恰是因为家长之间的矛盾而分手。到了如今，她却笑着对我说：“这些故事，我已记不太清楚了，你怎么还记得？”";




#pragma mark -- 全网搜索
- (NSString*)htmlStr {
    NSString *str = @"http://m.56shuku.org/files/article/html/0/126/21112.html";
//    NSString *str = @"https://m.biqiuge.com/book_24277/27258538.html";//天籁
    NSData *htmlData = [[NSData alloc]initWithContentsOfURL:[NSURL URLWithString:str]];
    NSString *result = [[NSString alloc] initWithData:htmlData  encoding:NSUTF8StringEncoding];
    if (!result) {
        NSStringEncoding myEncoding = CFStringConvertEncodingToNSStringEncoding (kCFStringEncodingGB_18030_2000);
        result = [[NSString alloc] initWithData:htmlData  encoding:myEncoding];
    }
    return result;
}

@end
