//
//  LDReader.h
//  LDReader
//
//  Created by mengminduan on 2017/10/11.
//  Copyright © 2017年 mengminduan. All rights reserved.
//  1.0.2

#import <UIKit/UIKit.h>
#import "LDConfiguration.h"
#import "LDChapterModel.h"
#import "LDBookModel.h"
#import "LDReaderConstants.h"

typedef NS_ENUM(NSUInteger, LDReaderState) {
    LDReaderBusy,
    LDReaderReady,
};
@class LDReader;
UIKIT_EXTERN NSString *const LDReaderVersion;
@protocol LDReaderDelegate <NSObject>
@optional
/*
 * called when a new chapter needed
 * @param chapterIndex Index of the chapter
 * @note the method would not be called if the reader started with a whole txt book, rather than a single chapter
 */
- (void)reader:(LDReader *)reader needChapterWithIndex:(NSInteger)chapterIndex;
/*
 * called when reading progress updated
 * @param chapterIndex The index of the current chapter
 * @param pageCounts The total page counts of the chapter
 * @param pageIndex The index of the current page
 */
- (void)reader:(LDReader *)reader progressWithChapter:(NSInteger)chapterIndex pageCounts:(NSInteger)pageCounts pageIndex:(NSInteger)pageIndex currentWordIndex:(NSInteger)currentWordIndex;
/*
 * called when the state of the reader changed
 * @param state The state of the reader
 * @note When the reader starts to process data, such as parsing chapter content, the reader enters the busy state.
 * when the reader finishes processing data, the reader enters the ready state. You can show users a loading
 * animation when the reader is busy, if you want the app to have a better user experience
 */
- (void)reader:(LDReader *)reader readerStateChanged:(LDReaderState)state;
/*
 * called when the setting frame clicked
 */
- (void)readerDidClickSettingFrame:(LDReader *)reader;
/*
 * called when chapter comment button at the bottom of the screen clicked. see property commentEntryEnable.
 */
- (void)readerDidClickChapterComment:(LDReader *)reader;
/*
 * called when last page of the chapter needs to be displayed
 * @param tailView A view in which you can do some costom drawing
 * @param chapterIndex Index of the chapter
 * @note The remaining space on the last page of each chapter is not fixed, the size of tailView describes
 * the size of the remaining blank area on the last page, no matter what you draw, please do not exceed the
 * size of this view. All the content drawn on this view will be displayed in the remaining blank area on
 * the last page of the chapter. However, there is a special case that when the reader is switched to
 * continuous scroll mode(LDReaderScrollVertical), you can reset the height of this view, that is, its height
 * depends on what you need to draw, You are free to set the height of this view to include all the content
 * you need to draw, the reader will show everything you draw
 */
- (void)reader:(LDReader *)reader chapterTailView:(UIView *)tailView chapterIndex:(NSInteger)chapterIndex;


/**
 Callback to the advertisement view showing the current page

 @param reader current reader
 @param advertisingView View for displaying advertisements
 @param chapterIndex Current Chapter Index,start from 1.
 @param pageIndex Index of the current page,start from 1.
 */
- (void)reader:(LDReader *)reader advertisingView:(UIView *)advertisingView chapterIndex:(NSInteger)chapterIndex andPageIndex:(NSInteger)pageIndex;


/*
 * called when the error occurred
 * @param error An object describing error occurred in the reader.
 * @note error code are as follow:
 * -8000        reader io error
 * -8001        long press operation is not supported in continuous scroll mode(LDReaderScrollVertical)
 * -8002        wrong text encoding
 * -8003        arrived first page
 * -8004        arrived last page. We do not know when reader reach the last page, so reader will call back
 *              on the last page of each chapter.
 */
- (void)reader:(LDReader *)reader failedWithError:(NSError *)error;
/*
 * called when the chapter directory of the book is completely parsed
 * @param titles An array contains the information of all chapters. see the demo for details of how to use this param
 * @note the method would only be called when the reader started with a whole txt book, rather than a single
 * chapter
 */
- (void)reader:(LDReader *)reader chapterTable:(NSArray *)chapterTable;
/*
 * called when the menu item that added to the pop-up menu clicked
 * @param title Title of menu item
 * @param contentStr Selected content
 * @param range Range of selected content
 * @note The method would not be called if you didn't set menuTitles of reader. see property menuTitles
 */
- (void)reader:(LDReader *)reader menuItemClickWithTitle:(NSString *)title andContentString:(NSString *)contentStr andSelectedRange:(NSRange)range;


/**
 The callback is currently reading the content of the page
 @param reader current reader.
 @param currentPageString The text content of the current page
 */
- (void)reader:(LDReader *)reader currentPageWithPageString:(NSString *)currentPageString;

/**
 The callback is used to return all page contents of the current chapter.
 @param reader reader
 @param pages     The content of all pages in the current chapter
 @param chapterIndex currentChapterIndex
 */
- (void)reader:(LDReader *)reader currentChapterWithPages:(NSArray *)pages currentChapterIndex:(NSInteger)chapterIndex;

@end


@interface LDReader : UIViewController
/*
 * A singleton object describing the configuration of the reader,
 * use shareConfiguration to gain the configuration object and do
 * some custom configuration. Default configuration would be used
 * if you did nothing
 */
@property (nonatomic, strong) LDConfiguration *configuration;
/*
 * A model object describing the basic information of the book
 */
@property (nonatomic, strong) LDBookModel *bookModel;
/*
 * A model object describing the information of a chapter
 * @note This is a readonly property and you can just gain information
 * of the current chapter
 */
@property (nonatomic, strong, readonly) LDChapterModel *chapterModel;


/**
 * This property is used to describe the location of the last reading
 * If there is a historical record, the attribute must have a value
 * If there is no history, please set it to 0 or not.
 */
@property (nonatomic, assign) NSInteger lastReadWordIndex;

/*
 * This object describes a set of menu titles. When the user triggers a
 * long press operation, the reader will pop up a group of menu items,
 * you can customize some menu items which will be added to the pop-up
 * menu through this object.
 */
@property (nonatomic, strong) NSArray *menuTitles;


/**
 * This property is used to mark whether it is a jump chapter , page or automatic page operation.
 *
 * When the active jump, the page, or the automatic page is set to YES
 */
@property (nonatomic, assign) BOOL manualJumpChapterOrPage;


/**
 * This property is used to specify the paragraph index that is being read.
 * The minimum value is 0.
 * -1 stands for automatic reading mode to clear the currently selected paragraphs.
 */
@property (nonatomic, assign) NSInteger selectedParagraphIndex;


/*
 * The reader's delegate
 */
@property (nonatomic, weak) id<LDReaderDelegate> delegate;

/*
 * start a reader with a single chapter
 * @param chapterModel Model that contains the chapter information
 * @param pageIndex Page index which reader start from
 * @note there are two ways to describe a chapter, which can be
 * parsed and displayed on the screen later. The first way is to
 * set the chapter model‘s path on which the chapter data is stored
 * as a text file. Another way is to set chapter model's contentString
 * which contains the whole chapter data
 */
- (void)readWithChapter:(LDChapterModel *)chapterModel pageIndex:(NSInteger)pageIndex;

/*
 * start a reader with the path of a whole txt book
 * @param path Path of the txt book
 * @parm chapterIndex Starting from 1
 * @param pageIndex Page index which Starting from 1
 */
- (void)readWithFilePath:(NSString *)path andChapterIndex:(NSInteger)chapterIndex pageIndex:(NSInteger)pageIndex;


/**
 * Resetting the multiple attribute values of the reader
 * You can use the keys in the LDReaderConstants.h file
 @param dictionary  for example @{LDTextColor:[UIColor blackColor]}
 */
- (void)resettingReaderConfigurationWithDictionary:(NSDictionary *)dictionary;

@end




