//
//  DataParser.h
//  LDReader
//
//  Created by mengminduan on 2017/10/11.
//  Copyright © 2017年 mengminduan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "LDChapterModel.h"
#import "LDPageModel.h"
#import "LDBookModel.h"
#import "LDConfiguration.h"


extern NSString *LDDataParserMD5STR;
extern NSStringEncoding LDDataParserEncodeMethod;
@interface LDDataParser : NSObject

- (NSAttributedString *)attrbutedStringFromChapterModel:(LDChapterModel *)chapter configuration:(LDConfiguration *)configuration;

- (void)cutPageWithAttributedString:(NSAttributedString *)attrString configuration:(LDConfiguration *)configuration chapterIndex:(NSInteger)chapterIndex andChapterMarkArray:(NSMutableArray *)chapterMarkArray completeProgress:(void(^)(NSInteger, LDPageModel *, BOOL))callback;

- (void)extractChapterWithBookContent:(NSString *)content bookModel:(LDBookModel *)bookModel chapterIndex:(NSInteger)currentChapterIndex complete:(void(^)(NSArray *,BOOL,BOOL))callback;

- (LDChapterModel *)changeChapterModelWithPath:(LDChapterModel *)chapter bookModel:(LDBookModel*)bookModel;

@end
