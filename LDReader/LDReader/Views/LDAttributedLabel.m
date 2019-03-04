//
//  LDAttributedLabel.m
//  LDReader
//
//  Created by 刘洪 on 2017/11/2.
//  Copyright © 2017年 刘洪. All rights reserved.
//

#import "LDAttributedLabel.h"
#import <objc/message.h>
#import "LDMagnifierView.h"
#import "LDMarkItem.h"
#import "LDConfiguration.h"
#import "LDLog.h"

@interface LDAttributedLabel()
{
    BOOL _magnifierEnable;
    BOOL _touchBeginIsLeftCursorArea;
}

@property (nonatomic, strong) UIMenuController *menuController;

//选中区域
@property (nonatomic, assign) NSRange selectRange;

@property (nonatomic, strong) NSMutableArray *pathArray;

@property (nonatomic, assign) BOOL selectState;

@property (nonatomic, assign) CGRect menuRect;

@property (nonatomic,strong) LDMagnifierView *magnifierView;

@property (nonatomic, assign) CGRect leftCursor;

@property (nonatomic, assign) CGRect rightCursor;

@property (nonatomic, strong) UIPanGestureRecognizer *pan;

@property (nonatomic, strong) UITapGestureRecognizer *tap;

@property (nonatomic, strong) NSArray *lineArray;

@property (nonatomic, strong) LDConfiguration *configuration;

@property (nonatomic, assign) NSInteger preSelectedParagraphIndex;

@end


@implementation LDAttributedLabel
@synthesize markList = _markList;

-(instancetype)initWithFrame:(CGRect)frame
{
    @throw [NSException exceptionWithName:@"LDAttributeLabelError" reason:@"Please call '-initWithFrame:andConfiguration:' to init" userInfo:nil];
}

- (instancetype)initWithFrame:(CGRect)frame andConfiguration:(LDConfiguration *)configuration
{
    self = [super initWithFrame:frame];
    if (self) {
        _configuration = configuration;
        [self initialSetting];
    }
    return self;
}

- (void)initialSetting
{
    _selectedParagraphIndex = -1;
//    self.configuration = [LDConfiguration shareConfiguration];
    [self addGestureRecognizer];
    [self loadMenuController];
}

- (void)addGestureRecognizer
{
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(longPress:)];
    [self addGestureRecognizer:longPress];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(pan:)];
    pan.enabled = NO;
    _pan = pan;
    [self addGestureRecognizer:pan];
    
}

- (void)loadMenuController
{
    _menuController = [UIMenuController sharedMenuController];
    
}

-(void)longPress:(UILongPressGestureRecognizer *)longPress
{
    if (self.configuration.scrollType != LDReaderScrollVertical && _menuTitles.count) {
        CGPoint point = [longPress locationInView:self];
        //     || longPress.state == UIGestureRecognizerStateChanged
        if (longPress.state == UIGestureRecognizerStateBegan) {
            DLog(@"longPress");
            NSInteger index = [self closestCursorIndexToPoint:point];
            DLog(@"index == %zd",index);
//            [self textAttachmentWithSelectRange];
            for (NSValue *rangeValue in _layoutFrame.paragraphRanges) {
                DLog(@"rangeValue == %@",rangeValue);
                NSRange range = [rangeValue rangeValue];
                if (index >= range.location && (index <= (range.location + range.length))) {
                    _selectRange = NSMakeRange(range.location, range.length);
                    DLog(@"selectRange == %@",NSStringFromRange(range));
                }
            }
            [self updateSelectPath];
            [self setNeedsDisplay];
            if (longPress.state == UIGestureRecognizerStateEnded) {
                [_magnifierView removeFromSuperview];
                _magnifierView = nil;
                [self hiddenMagnifier];
            }
            if (!CGRectEqualToRect(_menuRect, CGRectZero) && _selectRange.length > 0) {
                [self showMenuController];
            }
        }
    }else if(self.configuration.scrollType == LDReaderScrollVertical){
        if (longPress.state == UIGestureRecognizerStateBegan) {
            if(self.canNotShowMenuBlock){
            self.canNotShowMenuBlock();
            }
        }
    }
}


-(void)pan:(UIPanGestureRecognizer *)pan {
    CGPoint point = [pan locationInView:self];
    CGRect leftTouchArea = CGRectNull;
    CGRect rightTouchArea = CGRectNull;
    bool touchBeginRightArea = NO;
    
    [self hiddenMenuController];
    
    if (pan.state == UIGestureRecognizerStateBegan) {
//        magnifierEnable = NO;
        int offset = 15;
        leftTouchArea = CGRectMake(CGRectGetMinX(_leftCursor) - offset, CGRectGetMinY(_leftCursor) - offset, CGRectGetWidth(_leftCursor) + offset * 2, CGRectGetHeight(_leftCursor) + offset * 2);
        rightTouchArea = CGRectMake(CGRectGetMinX(_rightCursor) - offset, CGRectGetMinY(_rightCursor) - offset, CGRectGetWidth(_rightCursor) + offset * 2, CGRectGetHeight(_rightCursor) + offset * 2);
        _touchBeginIsLeftCursorArea = CGRectContainsPoint(leftTouchArea, point) ;
        touchBeginRightArea =  CGRectContainsPoint(rightTouchArea, point);
        if (_touchBeginIsLeftCursorArea || touchBeginRightArea) {
            _magnifierEnable = YES;
        }
    }
    if (pan.state == UIGestureRecognizerStateBegan || pan.state == UIGestureRecognizerStateChanged) {
        if (_magnifierEnable) {
            [self selectRangeWithPoint:point isLeftCursor:_touchBeginIsLeftCursorArea];
            [self updateSelectPath];
            [self setNeedsDisplay];
        }
    }
    if (pan.state == UIGestureRecognizerStateEnded) {
        [self hiddenMagnifier];
        if (!CGRectEqualToRect(_menuRect, CGRectZero)) {
            [self showMenuController];
        }
        _touchBeginIsLeftCursorArea = NO;
        _magnifierEnable = NO;
    }
}

- (void)showMenuController
{
    [self becomeFirstResponder];
    if (!_tap) {
        self.tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tap:)];
        [self addGestureRecognizer:self.tap];
    }
    //设置菜单最终显示的位置
    CGRect targetRect = CGRectMake(_menuRect.origin.x, CGRectGetMinY(_menuRect), CGRectGetWidth(_menuRect), CGRectGetHeight(_menuRect));
    [_menuController setTargetRect:targetRect inView:self];
    [_menuController setMenuVisible:YES animated:YES];
}

-(void)tap:(UITapGestureRecognizer *)tap{
    [self clickMenuItem];
}

- (void)hiddenMenuController
{
    [_menuController setMenuVisible:NO animated:NO];
    [self resignFirstResponder];
    if (_tap) {
        [self removeGestureRecognizer:self.tap];
        self.tap = nil;
    }
}

- (void)menuItemClick:(NSString *)menuTitle
{
    NSString *string = [_layoutFrame.attributedStringFragment.string substringWithRange:_selectRange];
    NSRange range = NSMakeRange(_selectRange.location + _rangeInChapter.location, _selectRange.length);
    if ([menuTitle isEqualToString:@"标注"]) {
        if(range.length>0) [self addMarkListWithRange:range];
    }
//    else{
        if (self.menuItemClockClick) {
            [self resignFirstResponder];
            self.menuItemClockClick(menuTitle,string,range);
            DLog(@"%@",menuTitle);
        }
//    }
    [self clickMenuItem];
}

- (void)addMarkListWithRange:(NSRange)range
{
    
    if (!self.markList.count) {
        [self.markList addObject:[NSValue valueWithRange:range]];
        return;
    }
    __block BOOL isNewRange = NO;
    [self.markList enumerateObjectsUsingBlock:^(NSValue *rangeValue, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange oldRange = rangeValue.rangeValue;
        if (range.location + range.length > oldRange.location && range.location +range.length < oldRange.location+oldRange.length) {
            [self.markList removeObject:rangeValue];
            [self.markList addObject:[NSValue valueWithRange:range]];
            isNewRange = NO;
            *stop = YES;
        }else if (range.location >= oldRange.location && range.location < oldRange.location + oldRange.length){
            [self.markList removeObject:rangeValue];
            [self.markList addObject:[NSValue valueWithRange:range]];
            isNewRange = NO;
            *stop = YES;
        }else if (range.location <= oldRange.location && range.location+range.length >= oldRange.location+oldRange.length){
            [self.markList removeObject:rangeValue];
            [self.markList addObject:[NSValue valueWithRange:range]];
            isNewRange = NO;
            *stop = YES;
        }
        else{
            isNewRange = YES;
        }
    }];
    
    if (isNewRange) {
        [self.markList addObject:[NSValue valueWithRange:range]];
    }
    
    DLog(@"self.markList= =%@",self.markList);
}

- (void)clickMenuItem{
    if (_pathArray.count==0 || !_pathArray || !_selectState) {
        return;
    }
    [self hiddenMenuController];
    _selectRange = NSMakeRange(0, 0);
    [self updateSelectPath];
    DLog(@"clickMenuItem  setNeedsDisplay");
    [self setNeedsDisplay];
}

-(NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    if ([super methodSignatureForSelector:aSelector]) {
        return [super methodSignatureForSelector:aSelector];
    }
    return [super methodSignatureForSelector:@selector(menuItemClick:)];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSString *selStr =NSStringFromSelector([anInvocation selector]);
    NSRange range = [selStr rangeOfString:@"ld_"];
    if (range.location == 0) {
        [self menuItemClick:[selStr substringFromIndex:3]];
    }else{
        [super forwardInvocation:anInvocation];
    }
}

-(void)setSelectedParagraphIndex:(NSInteger)selectedParagraphIndex
{
    if (selectedParagraphIndex == -1) {
        _preSelectedParagraphIndex = _selectedParagraphIndex;
    }
    _selectedParagraphIndex = selectedParagraphIndex;
    [self setNeedsDisplay];
}

#pragma mark UIMenuController相关
- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    NSString *sel = NSStringFromSelector(action);
    NSRange match = [sel rangeOfString:@"ld_"];
    if (match.location == 0) {
        return YES;
    }
    return NO;
}
-(void)setMenuTitles:(NSArray<NSString *> *)menuTitles
{
    _menuTitles = menuTitles;
    NSMutableArray *menuItems = [NSMutableArray array];
    [menuTitles enumerateObjectsUsingBlock:^(NSString *title, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *sel = [NSString stringWithFormat:@"ld_%@",title];
        UIMenuItem *item = [[UIMenuItem alloc]initWithTitle:title action:NSSelectorFromString(sel)];
        [menuItems addObject:item];
    }];
    _menuController.menuItems = menuItems;
}


#pragma  mark 选中区域相关
-(void)updateSelectPath {
    
    if (!_pathArray) {
        _pathArray = [NSMutableArray array];
    }
    [_pathArray removeAllObjects];
    
    _pathArray = [self pathArrWithRange:_selectRange];
    
    if (_pathArray.count > 0) {
        _menuRect =CGRectFromString(_pathArray.firstObject);
        _selectState = YES;
    } else {
        _selectState = NO;
    }
}


- (NSMutableArray*)pathArrWithRange:(NSRange)range {
    DTCoreTextLayoutLine *line = [_layoutFrame lineContainingIndex:range.location];
    NSInteger index = line.attachments.count ? range.location+1 : range.location;
    NSInteger selectMaxIndex = range.location + range.length;
    NSMutableArray *arr = [NSMutableArray array];
    while (line.stringRange.location < selectMaxIndex) {
        NSInteger lineMaxIndex = line.stringRange.location + line.stringRange.length;
        CGFloat startOffset = [line offsetForStringIndex:index];
        CGFloat startX = line.frame.origin.x + startOffset;
        CGFloat endOffset = lineMaxIndex <= selectMaxIndex ? [line offsetForStringIndex:lineMaxIndex] : [line offsetForStringIndex:selectMaxIndex];
        CGFloat endX = line.frame.origin.x + endOffset;
//        if (!self.imageArr) {
            [arr addObject:NSStringFromCGRect(CGRectMake(startX, line.frame.origin.y, endX - startX, line.frame.size.height))];
//        } else {
//            for (DTGCImageModel *imageItem in self.imageArr) {
//                if (!CGRectContainsPoint(imageItem.frame, CGPointMake(CGRectGetMidX(line.frame), CGRectGetMidY(line.frame)))) {
//                    [arr addObject:NSStringFromCGRect(CGRectMake(startX, line.frame.origin.y, endX - startX, line.frame.size.height))];
//                }
//            }
//        }
        
        index = lineMaxIndex;
        line = [_layoutFrame lineContainingIndex:index];
        index = line.attachments.count ? index + 1 : index;
        if (!line) {
            break;
        }
        
        if (lineMaxIndex == selectMaxIndex) {
            break;
        }
    } ;
    return arr;
}

-(void)drawSelectedParagraphWithContext:(CGContextRef)ctx{
    if (_selectedParagraphIndex == -1) {
        [self drawSelectedParagraphWithIndex:_preSelectedParagraphIndex context:ctx andColor:[UIColor clearColor]];
    }else{
        [self drawSelectedParagraphWithIndex:_selectedParagraphIndex context:ctx andColor:_configuration.autoSelectedParagraphColor];
    }
}

-(void)drawSelectedParagraphWithIndex:(NSInteger)index context:(CGContextRef)ctx andColor:(UIColor *)drawColor{
    for (int i = 0; i<_layoutFrame.paragraphRanges.count; i++) {
        if (i == index) {
            NSRange paragraphRange = [_layoutFrame.paragraphRanges[i] rangeValue];
            if (paragraphRange.length == 1)return;
            UIColor *selectedColor = drawColor;
            CGContextSetFillColorWithColor(ctx, selectedColor.CGColor);
            NSArray *pathArray = [self pathArrWithRange:paragraphRange];
            CGMutablePathRef path = CGPathCreateMutable();
            for (int i = 0; i<pathArray.count; i++) {
                CGRect rect = CGRectFromString(pathArray[i]);
                CGPathAddRect(path, NULL, rect);
            }
            CGContextAddPath(ctx, path);
            CGContextFillPath(ctx);
            CGPathRelease(path);
            break;
        }
    }
}

-(void)drawSelectedPathWithContext:(CGContextRef)ctx {
    if (!_pathArray.count) {
        _pan.enabled = NO;
        return;
    }
    
//    BOOL isNightMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"OOReaderIsNightMode"];
    int dotWidth = 8;
    int cursorWidth = 3;
    self.leftCursor = CGRectNull;
    self.rightCursor = CGRectNull;
    _pan.enabled = YES;
    CGMutablePathRef _path = CGPathCreateMutable();
//    UIColor *selectedColor = isNightMode ? [UIColor colorWithRed:.5 green:.5 blue:.5 alpha:.3] : [UIColor colorWithRed:.5 green:.5 blue:.5 alpha:.5];
    UIColor *selectedColor = [UIColor colorWithRed:.5 green:.5 blue:.5 alpha:.5];
    CGContextSetFillColorWithColor(ctx, selectedColor.CGColor);
    for (int i = 0; i < [_pathArray count]; i++) {
        CGRect rect = CGRectFromString([_pathArray objectAtIndex:i]);
        CGPathAddRect(_path, NULL, rect);
        
        if (i == 0) {
            self.leftCursor = CGRectMake(rect.origin.x - cursorWidth, rect.origin.y, cursorWidth, rect.size.height);
        }
        if (i == [_pathArray count]-1) {
            self.rightCursor = CGRectMake(CGRectGetMaxX(rect), rect.origin.y, cursorWidth, rect.size.height);
        }
    }
    CGContextAddPath(ctx, _path);
    CGContextFillPath(ctx);
    
//    UIColor *cusorColor = isNightMode ? [UIColor colorWithRed:.7 green:.7 blue:.7 alpha:1] : [UIColor colorWithRed:.2 green:.2 blue:.2 alpha:1];
    UIColor *cusorColor = [UIColor colorWithRed:.2 green:.2 blue:.2 alpha:1];
    CGContextSetFillColorWithColor(ctx, cusorColor.CGColor);
    CGContextAddRect(ctx, self.leftCursor);
    CGContextAddRect(ctx, self.rightCursor);
    CGContextAddEllipseInRect(ctx, CGRectMake(CGRectGetMidX(self.leftCursor) - dotWidth/2, self.leftCursor.origin.y - dotWidth, dotWidth, dotWidth));
    CGContextAddEllipseInRect(ctx, CGRectMake(CGRectGetMidX(self.rightCursor) - dotWidth/2, CGRectGetMaxY(self.rightCursor), dotWidth, dotWidth));
    CGContextFillPath(ctx);
    CGPathRelease(_path);
}


- (void)selectRangeWithPoint:(CGPoint)point isLeftCursor:(BOOL)isLeftCursor{
    [self showMagnifier];
    self.magnifierView.touchPoint = point;
    
    NSInteger newIndex = [_layoutFrame closestCursorIndexToPoint:point];
    
    if (newIndex == _selectRange.location) {
        return;
    }
    
    if (isLeftCursor) {
        if (newIndex >= _selectRange.location + _selectRange.length) {
            return;
        }
        _selectRange = NSMakeRange(newIndex, _selectRange.location + _selectRange.length - newIndex);
    } else {
        if (newIndex <= _selectRange.location) {
            return;
        }
        _selectRange = NSMakeRange(_selectRange.location,newIndex - _selectRange.location);
        CGFloat abs  = [UIScreen mainScreen].bounds.size.width;
        if (point.x >= (abs - self.edgeInsets.right)) {
            _selectRange = NSMakeRange(_selectRange.location, _selectRange.length + 1);
            return;
        }
        if (point.x >=  self.edgeInsets.right) {
            _selectRange = NSMakeRange(_selectRange.location, _selectRange.length);
        }
    }
}

#pragma mark-Magnifier View

-(void)showMagnifier
{
    if (!_magnifierView) {
        self.magnifierView = [[LDMagnifierView alloc] init];
        self.magnifierView.readView = self.readerView;
//        [self addSubview:self.magnifierView];
        [[UIApplication sharedApplication].keyWindow addSubview:self.magnifierView];
    }
}

-(void)hiddenMagnifier
{
    if (_magnifierView) {
        [self.magnifierView removeFromSuperview];
        self.magnifierView = nil;
    }
}

#pragma mark -super
-(void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx
{
    [super drawLayer:layer inContext:ctx];
    [self drawSelectedPathWithContext:ctx];
    [self drawMarkListhWithContext:ctx];
    [self drawSelectedParagraphWithContext:ctx];
}

#pragma mark-

-(NSMutableArray *)markList
{
    if (!_markList) {
        _markList = [NSMutableArray array];
    }
    return _markList;
}

- (void)setMarkList:(NSMutableArray *)markList {
    _markList = markList;
    [self calculateMarkLineArr];
    [self setNeedsDisplay];
}

- (void)calculateMarkLineArr {
    if (_lineArray) {
        _lineArray = nil;
    }
    _lineArray = [NSArray array];
    __block NSMutableArray *muArr = [NSMutableArray array];
    NSInteger maxIndex = _rangeInChapter.location + _rangeInChapter.length;
    [_markList enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange range = [(NSValue*)obj rangeValue];
        if (range.location >= _rangeInChapter.location  && range.location + range.length <= maxIndex) {
            NSMutableArray *path = [self pathArrWithRange:NSMakeRange(range.location - _rangeInChapter.location, range.length)];
            [path enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                CGRect rect = CGRectFromString(obj);
                CGFloat y = CGRectGetMaxY(rect) + 2;
                LDMarkItem *item = [[LDMarkItem alloc] init];
                item.startPoint = CGPointMake(rect.origin.x, y);
                item.endPoint = CGPointMake(CGRectGetMaxX(rect), y);
                item.range = range;
                item.lastLine = (idx == path.count - 1);
                [muArr addObject:item];
            }];
        }
    }];
    self.lineArray = [muArr copy];
}
-(void)drawMarkListhWithContext:(CGContextRef)ctx {
    
//    if (needReDrawMarkList) {
        [self calculateMarkLineArr];
//        needReDrawMarkList = NO;
//    }
    
    [self.lineArray enumerateObjectsUsingBlock:^(LDMarkItem* item, NSUInteger idx, BOOL * _Nonnull stop) {
        
        CGFloat fontSize = 12;
        UIColor *color = [UIColor colorWithRed:0 green:0 blue:0 alpha:.3];
        
        CGContextSetStrokeColorWithColor(ctx, color.CGColor);
        CGContextSetLineWidth(ctx, 2);
        CGContextMoveToPoint(ctx, item.startPoint.x, item.startPoint.y);
        CGContextAddLineToPoint(ctx, item.endPoint.x, item.endPoint.y);
        CGContextDrawPath(ctx, kCGPathStroke);
        if (item.lastLine) {
            CGContextSetFillColorWithColor(ctx, color.CGColor);
            CGContextAddEllipseInRect(ctx, CGRectMake(item.endPoint.x, item.endPoint.y - fontSize/2,fontSize, fontSize));
            CGContextFillPath(ctx);
            CGContextDrawPath(ctx, kCGPathFill);
            [self toDrawTextWithRect:CGRectMake(item.endPoint.x, item.endPoint.y - fontSize/2,fontSize, fontSize) str:@"注" context:ctx];
        }
    }];
}

- (void)toDrawTextWithRect:(CGRect)rect str:(NSString*)str1 context:(CGContextRef)context{
    if( str1 == nil || context == nil)
        return;
    UIGraphicsPushContext( context );
    CGContextSetLineWidth(context, 2);
    CGContextSetRGBFillColor (context, 0.01, 0.01, 0.01, 1);
    
    NSMutableParagraphStyle *textStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    textStyle.lineBreakMode = NSLineBreakByWordWrapping;
    textStyle.alignment = NSTextAlignmentCenter;
    UIFont  *font = [UIFont boldSystemFontOfSize:8.0];
    NSDictionary *attributes = @{NSFontAttributeName:font, NSParagraphStyleAttributeName:textStyle,NSForegroundColorAttributeName :[UIColor whiteColor]};
    CGSize strSize = [str1 sizeWithAttributes:attributes];
    CGFloat marginTop = (rect.size.height - strSize.height)/2;
    CGRect r = CGRectMake(rect.origin.x, rect.origin.y + marginTop,rect.size.width, strSize.height);
    [str1 drawInRect:r withAttributes:attributes];
}




@end
