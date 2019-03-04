//
//  DTCoreTextLayoutFrame+LDExtension.m
//  LDReader
//
//  Created by 刘洪 on 2018/10/16.
//  Copyright © 2018年 刘洪. All rights reserved.
//

#import "DTCoreTextLayoutFrame+LDExtension.h"
#import "DTCoreTextLayoutLine.h"
#import "DTCoreTextGlyphRun.h"
#import <objc/runtime.h>
extern CGFloat advertisingHeight_;
extern NSString * const LDAdvertising;
extern NSString * const LDLastAdvertising;
static  CGFloat const lastAdvertisingMergin = 5.0;
//NSString * const LDLineSpace = @"lineSpacing";
static NSString * const LDParagraphStyle = @"NSParagraphStyle";
@implementation DTCoreTextLayoutFrame (LDExtension)

-(void)setAdvertisingTop:(CGFloat)advertisingTop
{
    objc_setAssociatedObject(self, @selector(advertisingTop), @(advertisingTop), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(CGFloat)advertisingTop
{
    return [objc_getAssociatedObject(self, _cmd) floatValue];
}

-(void)setAdvertisingBottom:(CGFloat)advertisingBottom
{
    objc_setAssociatedObject(self, @selector(advertisingBottom), @(advertisingBottom), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(CGFloat)advertisingBottom
{
    return [objc_getAssociatedObject(self, _cmd) floatValue];
}


+(void)load
{
    Method methode1 = class_getInstanceMethod(self, @selector(_ld_algorithmWebKit_BaselineOriginToPositionLine:afterLine:));
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
 Method methode2 = class_getInstanceMethod(self, @selector(_algorithmWebKit_BaselineOriginToPositionLine:afterLine:));
#pragma clang diagnostic pop
    method_exchangeImplementations(methode1, methode2);
}

- (CGPoint)_ld_algorithmWebKit_BaselineOriginToPositionLine:(DTCoreTextLayoutLine *)line afterLine:(DTCoreTextLayoutLine *)previousLine
{
    CGPoint baselineOrigin = [self _ld_algorithmWebKit_BaselineOriginToPositionLine:line afterLine:previousLine];
    
    DTCoreTextGlyphRun *preLineLastRun = previousLine.glyphRuns.lastObject;
    DTCoreTextGlyphRun *currentLineLastRun = line.glyphRuns.lastObject;
    NSMutableParagraphStyle *tmpParagraphStyle = currentLineLastRun.attributes[LDParagraphStyle];
    if ([tmpParagraphStyle respondsToSelector:@selector(lineSpacing)]) {
        baselineOrigin.y += tmpParagraphStyle.lineSpacing;
        if(preLineLastRun.attributes[LDAdvertising] && !currentLineLastRun.attributes[LDAdvertising] && !self.advertisingTop)
        {
            self.advertisingTop = CGRectGetMaxY(previousLine.frame);
            baselineOrigin.y += advertisingHeight_;
            self.advertisingBottom = baselineOrigin.y-line.frame.size.height;
        }else if (currentLineLastRun.attributes[LDLastAdvertising] && !self.advertisingTop) {//页面内容的最下面
            self.advertisingTop = baselineOrigin.y+lastAdvertisingMergin;
            self.advertisingBottom = self.advertisingTop + advertisingHeight_;
        }
    }
    return baselineOrigin;
}


@end
