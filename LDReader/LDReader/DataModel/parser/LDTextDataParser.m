//
//  LDTextDataParser.m
//  LDReader
//
//  Created by mengminduan on 2017/10/11.
//  Copyright © 2017年 mengminduan. All rights reserved.
//

#import "LDTextDataParser.h"
#import "DTCoreText.h"
#import "LDAttributedString.h"
#import "LDConvertor.h"
#import "NSString+MD5.h"

NSString *LDDataParserMD5STR;
NSStringEncoding LDDataParserEncodeMethod = NSUTF8StringEncoding;
static const NSInteger maxChapterLength_ = 4000;
NSString *_bookPath;
NSMutableArray *wholeBookChapterTitles_;
static NSString *const LDReaderAPPVerson = @"LDReaderAPPVerson";
@interface LDTextDataParser()
{
    NSMutableArray *_chapterArrays;
    NSInteger _currentChapterIndex;
//    NSMutableArray *_models;
}

@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic, strong) void (^callBack)(NSArray *array,BOOL completed,BOOL cached);
@property (nonatomic, strong) dispatch_queue_t taskQueue;
@end
@implementation LDTextDataParser

- (NSAttributedString *)attrbutedStringFromChapterModel:(LDChapterModel *)chapter configuration:(LDConfiguration *)configuration
{
//    从章节路径生成字符串
    NSError *error;
    NSString *tmpString = [NSString stringWithContentsOfFile:chapter.path encoding:NSUTF8StringEncoding error:&error];
    LDDataParserEncodeMethod = NSUTF8StringEncoding;
    if (!tmpString) {
        NSStringEncoding stringEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
        LDDataParserEncodeMethod = stringEncoding;
        tmpString = [NSString stringWithContentsOfFile:chapter.path encoding:stringEncoding error:&error];
    }
    
    if(!tmpString) {
        NSStringEncoding stringEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingHZ_GB_2312);
        LDDataParserEncodeMethod = stringEncoding;
        tmpString = [NSString stringWithContentsOfFile:chapter.path encoding:stringEncoding error:&error];
    }
    
    if (!tmpString) {
        LDDataParserEncodeMethod  = NSUnicodeStringEncoding;
        tmpString =[NSString stringWithContentsOfFile:chapter.path encoding:NSUnicodeStringEncoding error:&error];
    }
    if (!tmpString) {
        tmpString = chapter.contentString;
    }
    
    if (!tmpString) tmpString = @"";
    
    if (!configuration.isSimple) {
        tmpString = [[LDConvertor getInstance] s2t:tmpString];
    }
//  格式化字符串
    NSRange titleRange = NSMakeRange(0, 0);
    NSArray<NSTextCheckingResult *> *matchResult = [self getTitleMatchResults:tmpString];
    if (matchResult.count){
        titleRange = matchResult[0].range;
    }
    NSString *titleStr = [tmpString substringWithRange:titleRange];
    NSString *noTitleStr = [tmpString substringFromIndex:titleRange.location + titleRange.length];
    NSMutableArray *paragraph = [self formatString:noTitleStr];
    
//    从字符串生成富文本字符串
    
//    标题属性
    NSDictionary *titleDic;
    if (titleStr && titleStr.length) {
        NSMutableParagraphStyle *titleParagraphStyle = [[NSMutableParagraphStyle alloc]init];
        titleParagraphStyle.alignment = configuration.chapterTitleAlignment;
        titleParagraphStyle.lineSpacing = configuration.lineSpacing;
        titleParagraphStyle.paragraphSpacing = configuration.lineSpacing*4;
        titleDic = @{NSFontAttributeName:[UIFont fontWithName:configuration.fontName size:configuration.fontSize*1.5],
                                   NSParagraphStyleAttributeName:titleParagraphStyle,
                                   NSForegroundColorAttributeName:configuration.textColor
                                   };
    }
    
//    正文属性
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init];
    paragraphStyle.alignment = NSTextAlignmentJustified;
    paragraphStyle.lineSpacing = configuration.lineSpacing;
    paragraphStyle.paragraphSpacing = configuration.lineSpacing*2;
    UIFont *font = [UIFont fontWithName:configuration.fontName size:configuration.fontSize];
    NSDictionary *dict = @{NSFontAttributeName:font,
                           NSParagraphStyleAttributeName:paragraphStyle,
                           NSForegroundColorAttributeName:configuration.textColor,
                           };
    
//    计算缩进宽度
    NSString *test = @"哈哈";
    CGSize testSize = [test boundingRectWithSize:CGSizeMake(100, CGFLOAT_MAX)
                                         options:NSStringDrawingUsesFontLeading | NSStringDrawingUsesLineFragmentOrigin
                                      attributes:@{NSFontAttributeName:font}
                                         context:nil].size;
//    生成富文本
    __block NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc]init];
    if (titleStr && titleStr.length) {
    NSString *titleString = [NSString stringWithFormat:@"%@\n", titleStr];
    attrString = [[NSMutableAttributedString alloc] initWithString:titleString attributes:titleDic];
    }
    if (paragraph.count) {
        [self insertCharacterWithAttrString:attrString width:testSize.width config:configuration];
    }
    [paragraph enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL *stop) {
        NSString *string = (NSString *)object;
        NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:string attributes:dict];
        [attrString appendAttributedString:attrStr];
        if (idx != paragraph.count - 1) {
            [self insertCharacterWithAttrString:attrString width:testSize.width config:configuration];
        }
    }];
    
//    自动设置章节标题
    if (!chapter.title) {
        chapter.title = titleStr;
    }
    return attrString;
}

- (NSMutableArray *)formatString:(NSString *)string
{
    NSArray *stringArr = [string componentsSeparatedByString:@"\n"];
    NSMutableArray *paragraphArray = [NSMutableArray array];
    for (int i = 0; i < stringArr.count; i++) {
        NSString *subString = stringArr[i];
        NSString *newString = [self transtoStandardStringWithString:subString];
        if (newString.length != 0) {
            if (i != stringArr.count - 1) {
                newString = [NSString stringWithFormat:@"%@\n", newString];
            }
            [paragraphArray addObject:newString];
        }
    }
    return paragraphArray;
}

- (NSString *)transtoStandardStringWithString:(NSString *)string
{
    NSString *newString0 = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//    NSString *newString1 = [newString0 stringByReplacingOccurrencesOfString:@" " withString:@""];
    return [newString0 stringByReplacingOccurrencesOfString:@"\t" withString:@""];
}

//整本书分成章节数组
- (void)extractChapterWithBookContent:(NSString *)content bookModel:(LDBookModel *)bookModel chapterIndex:(NSInteger)currentChapterIndex complete:(void(^)(NSArray *,BOOL,BOOL))callback;
{
//    _models = [NSMutableArray array];
    _currentChapterIndex = currentChapterIndex;
    _chapterArrays = [NSMutableArray array];
//    wholeBookChapterTitles_ = [NSMutableArray array];
    _callBack = callback;
    self.taskQueue = dispatch_queue_create("taskQueue", DISPATCH_QUEUE_CONCURRENT);
    self.semaphore = dispatch_semaphore_create(10);
    dispatch_async(dispatch_get_global_queue(0, 0), ^() {
        NSString *document =  NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *md5Str = [NSString stringWithFormat:@"%@-%@",bookModel.name,[content MD5]];
        LDDataParserMD5STR = md5Str;
        NSString *storePath = [document stringByAppendingPathComponent:@"ldreader-books"];
        _bookPath = [NSString stringWithFormat:@"%@/%@", storePath, md5Str];
        if (![[NSFileManager defaultManager] fileExistsAtPath:_bookPath]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:_bookPath withIntermediateDirectories:YES attributes:nil error:nil];
        }else{
            NSArray *array = [self _wholeBookChaptersFromCache];
            if (array && array.count) {
                wholeBookChapterTitles_ = (NSMutableArray *)array;
                callback(array,YES,YES);
                return;
            }
        }
        NSArray<NSTextCheckingResult *> *matchResults;
        matchResults = [self getTitleMatchResults:content];
        __block NSInteger endLocation = 0;
        NSInteger counts = matchResults.count;
        if(counts>0){
            NSString *preTitleStr = [content substringToIndex:matchResults[0].range.location];
            NSString *newString1 = [self transtoStandardStringWithString:preTitleStr];
            NSString *newString2 = [newString1 stringByReplacingOccurrencesOfString:@"\n" withString:@""];
            NSString *newString = [newString2 stringByReplacingOccurrencesOfString:@"\r" withString:@""];
            __block NSInteger tempIndex = 0;
            if (newString.length) {
               tempIndex = [self extractBigChapterWithContentString:preTitleStr preChapterCount:0 andChapterTitle:bookModel.name];
            }
            [matchResults enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull matchResult, NSUInteger i, BOOL * _Nonnull stop) {
                    NSString *currentTitle = [content substringWithRange:matchResult.range];
                    if (i == counts - 1) {
                        endLocation = content.length;
                    }else {
                        endLocation = matchResults[i + 1].range.location;
                    }
//                    NSLog(@"NSThread == %@",[NSThread currentThread]);
                    NSInteger startLocation = matchResults[i].range.location;
                    NSRange subRange = NSMakeRange(startLocation, endLocation - startLocation);
                    NSString *subString = [content substringWithRange:subRange];
                    tempIndex = [self extractBigChapterWithContentString:subString preChapterCount:tempIndex andChapterTitle:currentTitle];
            }];
        }else{
            if (content.length) {
                [self extractBigChapterWithContentString:content preChapterCount:0 andChapterTitle:bookModel.name];
            }else{//空文件
                [self genAndStoreChapterWithContent:@"" ChapterIndex:1 andChapterTitle:bookModel.name];
            }
        }
        [self _cacheWholeBookChapters];
        
    });
}

- (void) _cacheWholeBookChapters
{
    dispatch_async(self.taskQueue, ^{
        NSString *wholeBookPath = [NSString stringWithFormat:@"%@/chapterDicArray",_bookPath];
        [NSKeyedArchiver archiveRootObject:_chapterArrays toFile:wholeBookPath];
//        NSLog(@"_cacheWholeBookChapters == %@",[NSThread currentThread]);
        _callBack(_chapterArrays,YES,NO);
        
    });
}

- (NSArray *) _wholeBookChaptersFromCache
{
    NSString *wholeBookPath = [NSString stringWithFormat:@"%@/chapterDicArray",_bookPath];
    NSArray *chapterArray = [NSKeyedUnarchiver unarchiveObjectWithFile:wholeBookPath];
//    NSString *preAppVersion = [[NSUserDefaults standardUserDefaults] objectForKey:LDReaderAPPVerson];
//    NSString *currentAppVerson = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
//    #ifndef DEBUG
//    if ([preAppVersion isEqualToString:currentAppVerson]) {
//         return chapterArray;
//    }else{
//    #endif
//        [[NSUserDefaults standardUserDefaults] setObject:currentAppVerson forKey:LDReaderAPPVerson];
        NSMutableArray *tempArray = [NSMutableArray arrayWithCapacity:chapterArray.count];
        for (NSDictionary *chapterInfoDic in chapterArray) {
            NSMutableDictionary *tempChapterDic = chapterInfoDic.mutableCopy;
            NSString *path = tempChapterDic[@"path"];
            NSRange range = [path rangeOfString:@"/chapter"];
            NSString *subPath= [path substringWithRange:NSMakeRange(range.location, path.length-range.location)];
            path = [NSString stringWithFormat:@"%@%@",_bookPath,subPath];
            tempChapterDic[@"path"] = path;
            [tempArray addObject:tempChapterDic];
        }
        return tempArray;
//    #ifndef DEBUG
//    }
//    #endif
}

- (void)noTitleChapterWithContent:(NSString *)content withBookPath:(NSString *)bookPath models:(NSMutableArray *)models andChapterArrays:(NSMutableArray *)chapterArrays{
    NSString *chapterPath = [NSString stringWithFormat:@"%@/chapter1.txt",bookPath];
    LDChapterModel *chapterModel = [[LDChapterModel alloc]init];
    chapterModel.chapterIndex = 1;
    chapterModel.title = @"";
    chapterModel.path = chapterPath;
    [models addObject:chapterModel];
    [chapterArrays addObject:@{ @"index":@(1),
                                @"title":@"",
                                @"path":chapterPath}];
    [content writeToFile:chapterPath atomically:YES encoding:LDDataParserEncodeMethod error:nil];
}

- (void)genAndStoreChapterWithContent:(NSString *)content ChapterIndex:(NSInteger)chapterIndex andChapterTitle:(NSString *)chapterTitle{
    NSString *chapterPath = [NSString stringWithFormat:@"%@/chapter%zd.txt",_bookPath,chapterIndex];
    [_chapterArrays addObject:@{ @"index":@(chapterIndex),
                                @"title":chapterTitle,
                                @"path":chapterPath}];
    wholeBookChapterTitles_ = _chapterArrays;
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    if (![[NSFileManager defaultManager] fileExistsAtPath:chapterPath]) {//保存models,chapterArrays
        dispatch_async(self.taskQueue, ^{
          [content writeToFile:chapterPath atomically:YES encoding:LDDataParserEncodeMethod error:nil];
            if (chapterIndex == _currentChapterIndex && _callBack) {
                _callBack(_chapterArrays,NO,NO);
            }
                dispatch_semaphore_signal(self.semaphore);
        });
    }
}



- (NSArray<NSTextCheckingResult *> *)getTitleMatchResults:(NSString *)content
{
//    第[ ]*[0-9一二三四五六七八九十百千]*[ ]*[章回节].*
//    (第)([0-9零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,10})([章节回集卷])(.*)
//    [　 ]*《?\\(?\\[?第[一二三四五六七八九十百千万零\\d　 ]+(章|节|回|回合|章节|卷).*
//    [　 ]*《?\\(?\\[?第[一二三四五六七八九十百千万萬零\\d　 ]+(章|节|節|回|回合|章节|章節|卷).*
//    《?\\(?\\[?第[一二三四五六七八九十百千万萬零\\d　 ]+(章|节|節|回|回合|章节|章節|卷).*
    if([self isChinesecharacter:content]){
        NSString* regPattern = @"《?\\(?\\[?第[一二三四五六七八九十百千万萬零\\d　 ]+(章|节|節|回|回合|章节|章節|卷).*";
        NSError *error;
        NSRegularExpression *regExp = [NSRegularExpression regularExpressionWithPattern:regPattern options:(NSRegularExpressionCaseInsensitive) error:&error];
        NSArray<NSTextCheckingResult *> *matchResult = [regExp matchesInString:content options:(NSMatchingReportCompletion) range:NSMakeRange(0, content.length)];
        return matchResult;
    }else{
        return @[];
    }
}

- (BOOL)isChinesecharacter:(NSString *)string{
    
    if (string.length>100) {
        string = [string substringToIndex:100];
    }
    NSString *newString1 = [self transtoStandardStringWithString:string];
    NSString *newString2 = [newString1 stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    NSString *newString = [newString2 stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    if (string.length == 0) {
        return NO;
    }
    return [self enumerateChineseCharacterWithString:newString];
}

- (BOOL)enumerateChineseCharacterWithString:(NSString *)string
{
    unichar c;
    for (int i = 0; i<string.length; i++) {
        c = [string characterAtIndex:i];
        if (c >=0x4E00 && c <=0x9fff)     {
            //    0x9fff
            //    0x9FA5
            return YES;//汉字
        }
    }
    return NO;
}

// 大章节划分成若干小章节
- (NSInteger)extractBigChapterWithContentString:(NSString *)contentString preChapterCount:(NSInteger)preChapterCount andChapterTitle:(NSString *)chapterTitle
{
    NSString *tempString;
    NSInteger chapterIndex = 0;
    while (contentString.length>maxChapterLength_) {
        chapterIndex++;
        tempString = [contentString substringToIndex:maxChapterLength_];
        NSRange range = [[contentString substringFromIndex:maxChapterLength_] rangeOfParagraphAtIndex:0];
        tempString = [contentString substringToIndex:maxChapterLength_+range.length];
        // 创建并存储chapter
        NSString *tmpChapterTitle = [NSString stringWithFormat:@"%@(%zd)",chapterTitle,chapterIndex];
        [self genAndStoreChapterWithContent:tempString ChapterIndex:preChapterCount+chapterIndex andChapterTitle:tmpChapterTitle];
        contentString = [contentString substringFromIndex:tempString.length];
    }
    
    //创建并存储chapter
    if (contentString && contentString.length>0) {
        chapterTitle = chapterIndex == 0 ? chapterTitle :[NSString stringWithFormat:@"%@(%d)",chapterTitle,chapterIndex+1];
        chapterIndex += preChapterCount;
        [self genAndStoreChapterWithContent:contentString ChapterIndex:chapterIndex+1 andChapterTitle:chapterTitle];
        return chapterIndex + 1;
    }else{
        return chapterIndex + preChapterCount;
    }
}


- (LDChapterModel *)changeChapterModelWithPath:(LDChapterModel *)chapter bookModel:(LDBookModel *)bookModel
{
    NSString *document = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *storePath = [document stringByAppendingPathComponent:@"ldreader-books"];
    NSString *bookPath = [NSString stringWithFormat:@"%@/%@&%@", storePath, bookModel.name, bookModel.author];
    if (![[NSFileManager defaultManager] fileExistsAtPath:bookPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:bookPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *chapterPath = [NSString stringWithFormat:@"%@/chapter%ld.txt", bookPath, (long)chapter.chapterIndex];
    LDChapterModel *model = [LDChapterModel new];
    model.chapterIndex = chapter.chapterIndex;
    model.title = chapter.title;
    model.commentCounts = chapter.commentCounts;
    model.path = chapterPath;
    
    NSError *error;
    [chapter.contentString writeToFile:chapterPath atomically:YES encoding:LDDataParserEncodeMethod error:&error];
    if (error) {
        return nil;
    }else {
        return model;
    }
}

- (void)insertCharacterWithAttrString:(NSMutableAttributedString *)attrString width:(CGFloat)width config:(LDConfiguration *)configuration
{
    DTTextAttachment *attachment = [[DTTextAttachment alloc] init];
    attachment.displaySize = CGSizeMake(width, 20);
    
    NSMutableDictionary *newAttributes = [NSMutableDictionary new];
    [newAttributes setObject:attachment forKey:NSAttachmentAttributeName];
    CTRunDelegateRef embeddedObjectRunDelegate = createEmbeddedObjectRunDelegate((id)attachment);
    [newAttributes setObject:(__bridge id)embeddedObjectRunDelegate forKey:(id)kCTRunDelegateAttributeName];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init];
    paragraphStyle.alignment = NSTextAlignmentJustified;
    paragraphStyle.lineSpacing = configuration.lineSpacing;
    paragraphStyle.paragraphSpacing = configuration.lineSpacing*2;
    [newAttributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
    
    unichar replaceChar = 0xFFFC;
    NSString *content = [NSString stringWithCharacters:&replaceChar length:1];
    NSMutableAttributedString *space = [[NSMutableAttributedString alloc] initWithString:content attributes:newAttributes];
    [attrString appendAttributedString:space];
    
    CFRelease(embeddedObjectRunDelegate);
}


@end




