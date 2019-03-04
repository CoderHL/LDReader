//
//  LDTableView.h
//  LDReader
//
//  Created by 刘洪 on 2017/11/8.
//  Copyright © 2017年 刘洪. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, LDTableViewScrollDirection) {
    LDTableViewScrollDirectionTop,
    LDTableViewScrollDirectionBottom,
};

@interface LDTableView : UITableView
//章节首页
@property (nonatomic, assign) BOOL isFirstPage;
//章节尾页
@property (nonatomic, assign) BOOL isLastPage;

@property (nonatomic, assign) BOOL isReloadTableView;

@property (nonatomic, assign) LDTableViewScrollDirection tableViewScrollDirection;

@property (nonatomic, assign) BOOL isRemoved;
@property (nonatomic, assign) BOOL isReCute;
@property (nonatomic, assign) NSInteger tempCellIndex;
//标记当重分页的时候是否有上章节数组
@property (nonatomic, assign) BOOL isRequestNextChaper;
@property (nonatomic, assign) BOOL isRequestPreChaper;

@property (nonatomic, assign) NSInteger preDatasCount;
//记录上一个消失的cellIndex
@property (nonatomic, assign) NSInteger preEndCellIndex;

@property (nonatomic, assign) BOOL isHandleExceptional;

@end
