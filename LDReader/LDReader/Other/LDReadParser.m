//
//  LSYReadParser.m
//  LSYReader
//
//  Created by Labanotation on 16/5/30.
//  Copyright © 2016年 okwei. All rights reserved.
//

#import "LDReadParser.h"

@implementation LDReadParser

#pragma CTRunCallBack

static NSDictionary *CFRunInfo;

+(CFIndex)parserIndexWithPoint:(CGPoint)point frameRef:(CTFrameRef)frameRef
{
	CFIndex index = -1;
	CGPathRef pathRef = CTFrameGetPath(frameRef);
	CGRect bounds = CGPathGetBoundingBox(pathRef);
	NSArray *lines = (__bridge NSArray *)CTFrameGetLines(frameRef);
	if (!lines) {
		return index;
	}
	NSInteger lineCount = [lines count];
	CGPoint *origins = malloc(lineCount * sizeof(CGPoint)); //给每行的起始点开辟内存
	if (lineCount) {
		CTFrameGetLineOrigins(frameRef, CFRangeMake(0, 0), origins);
		for (int i = 0; i<lineCount; i++) {
			CGPoint baselineOrigin = origins[i];
			CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:i];
			CGFloat ascent,descent,linegap; //声明字体的上行高度和下行高度和行距
			CGFloat lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &linegap);
			
			NSDictionary *attributeDic = (NSDictionary *)CTFrameGetFrameAttributes(frameRef);
			NSInteger lineSpace = [[attributeDic objectForKey:@"linespace"] intValue];
			CGRect lineFrame = CGRectMake(baselineOrigin.x, CGRectGetHeight(bounds)-baselineOrigin.y-ascent, lineWidth, ascent+descent+linegap+lineSpace);    //没有转换坐标系左下角为坐标原点 字体高度为上行高度加下行高度
			if (CGRectContainsPoint(lineFrame,point)){
				index = CTLineGetStringIndexForPosition(line, point);
				break;
			}
		}
	}
	free(origins);
	return index;
	
}


+(NSArray *)parserRectsWithPoint:(CGPoint)point range:(NSRange *)selectRange frameRef:(CTFrameRef)frameRef paths:(NSArray *)paths
{
    CFIndex index = -1;
    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(frameRef);
    NSMutableArray *muArr = [NSMutableArray array];
    NSInteger lineCount = [lines count];
    CGPoint *origins = malloc(lineCount * sizeof(CGPoint)); //给每行的起始点开辟内存
    index = [self parserIndexWithPoint:point frameRef:frameRef];
    if (index == -1) {
        return paths;
    }
    if (!(index>(*selectRange).location)) {
        (*selectRange).length = (*selectRange).location-index+(*selectRange).length;
        (*selectRange).location = index;
    }
    else{
        (*selectRange).length = index-(*selectRange).location;
    }
//    NSLog(@"selectRange - %@",NSStringFromRange((*selectRange)));
    if (lineCount) {
        
        CTFrameGetLineOrigins(frameRef, CFRangeMake(0, 0), origins);
        for (int i = 0; i<lineCount; i++){
            CGPoint baselineOrigin = origins[i];
            CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:i];
            CGFloat ascent,descent,linegap; //声明字体的上行高度和下行高度和行距
            CTLineGetTypographicBounds(line, &ascent, &descent, &linegap);
            CFRange stringRange = CTLineGetStringRange(line);
            CGFloat xStart;
            CGFloat xEnd;
            NSRange drawRange = [self selectRange:NSMakeRange((*selectRange).location, (*selectRange).length) lineRange:NSMakeRange(stringRange.location, stringRange.length)];
            
            if (drawRange.length) {        
                xStart = CTLineGetOffsetForStringIndex(line, drawRange.location, NULL);
                xEnd = CTLineGetOffsetForStringIndex(line, drawRange.location+drawRange.length, NULL);
                CGRect rect = CGRectMake(xStart, baselineOrigin.y-descent, fabs(xStart-xEnd), ascent+descent);
                if (rect.size.width ==0 || rect.size.height == 0) {
                    continue;
                }
                [muArr addObject:NSStringFromCGRect(rect)];
            }
            
    }
        
}
    return muArr;
}

+(CGRect)parserRectWithPoint:(CGPoint)point range:(NSRange *)selectRange frameRef:(CTFrameRef)frameRef
{
	CFIndex index = -1;
	CGPathRef pathRef = CTFrameGetPath(frameRef);
	CGRect bounds = CGPathGetBoundingBox(pathRef);
	CGRect rect = CGRectZero;
	NSArray *lines = (__bridge NSArray *)CTFrameGetLines(frameRef);
	if (!lines) {
		return rect;
	}
	NSInteger lineCount = [lines count];
	CGPoint *origins = malloc(lineCount * sizeof(CGPoint)); //给每行的起始点开辟内存
	if (lineCount) {
		CTFrameGetLineOrigins(frameRef, CFRangeMake(0, 0), origins);
		for (int i = 0; i<lineCount; i++) {
			CGPoint baselineOrigin = origins[i];
			CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:i];
			CGFloat ascent,descent,linegap; //声明字体的上行高度和下行高度和行距
			CGFloat lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &linegap);
//			weiwanchen
			
			NSDictionary *attributeDic = (NSDictionary *)CTFrameGetFrameAttributes(frameRef);
			NSInteger lineSpace = [[attributeDic objectForKey:@"linespace"] intValue];
			lineSpace = 20;
			CGRect lineFrame = CGRectMake(baselineOrigin.x, CGRectGetHeight(bounds)-baselineOrigin.y-ascent, lineWidth, ascent+descent+linegap+lineSpace);    //没有转换坐标系左下角为坐标原点 字体高度为上行高度加下行高度
			if (CGRectContainsPoint(lineFrame,point)){
				CFRange stringRange = CTLineGetStringRange(line);
				index = CTLineGetStringIndexForPosition(line, point);
				CGFloat xStart = CTLineGetOffsetForStringIndex(line, index, NULL);
				CGFloat xEnd;
				//默认选中两个单位
				if (index > stringRange.location+stringRange.length-2) {
					xEnd = xStart;
					xStart = CTLineGetOffsetForStringIndex(line,index-2,NULL);
					(*selectRange).location = index-2;
				}
				else{
					xEnd = CTLineGetOffsetForStringIndex(line,index+2,NULL);
					(*selectRange).location = index;
				}
				
				(*selectRange).length = 2;
				rect = CGRectMake(origins[i].x+xStart,baselineOrigin.y-descent,fabs(xStart-xEnd), ascent+descent);
				
				break;
			}
		}
	}
	free(origins);
	return rect;
}


+(NSArray *)parserRectsWithPoint:(CGPoint)point range:(NSRange *)selectRange frameRef:(CTFrameRef)frameRef paths:(NSArray *)paths direction:(BOOL) direction
{
    CFIndex index = -1;
    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(frameRef);
    NSMutableArray *muArr = [NSMutableArray array];
    NSInteger lineCount = [lines count];
    CGPoint *origins = malloc(lineCount * sizeof(CGPoint)); //给每行的起始点开辟内存
    index = [self parserIndexWithPoint:point frameRef:frameRef];
    if (index == -1) {
        return paths;
    }
    if (direction) //从右侧滑动
    {
        if (!(index>(*selectRange).location)) {
            (*selectRange).length = (*selectRange).location-index+(*selectRange).length;
            (*selectRange).location = index;
        }
        else{
            (*selectRange).length = index-(*selectRange).location;
        }
    }
    else    //从左侧滑动
    {
        if (!(index>(*selectRange).location+(*selectRange).length)) {
            (*selectRange).length = (*selectRange).location-index+(*selectRange).length;
            (*selectRange).location = index;
        }
    }
    //    NSLog(@"selectRange - %@",NSStringFromRange((*selectRange)));
    if (lineCount) {
        
        CTFrameGetLineOrigins(frameRef, CFRangeMake(0, 0), origins);
        for (int i = 0; i<lineCount; i++){
            CGPoint baselineOrigin = origins[i];
            CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:i];
            CGFloat ascent,descent,linegap; //声明字体的上行高度和下行高度和行距
            CTLineGetTypographicBounds(line, &ascent, &descent, &linegap);
            CFRange stringRange = CTLineGetStringRange(line);
            CGFloat xStart;
            CGFloat xEnd;
            NSRange drawRange = [self selectRange:NSMakeRange((*selectRange).location, (*selectRange).length) lineRange:NSMakeRange(stringRange.location, stringRange.length)];
            
            if (drawRange.length) {
                xStart = CTLineGetOffsetForStringIndex(line, drawRange.location, NULL);
                xEnd = CTLineGetOffsetForStringIndex(line, drawRange.location+drawRange.length, NULL);
                CGRect rect = CGRectMake(xStart, baselineOrigin.y-descent, fabs(xStart-xEnd), ascent+descent);
                if (rect.size.width ==0 || rect.size.height == 0) {
                    continue;
                }
                [muArr addObject:NSStringFromCGRect(rect)];
            }
            
        }
        
    }
    return muArr;
}
+(NSRange)selectRange:(NSRange)selectRange lineRange:(NSRange)lineRange
{
    NSRange range = NSMakeRange(NSNotFound, 0);
    if (lineRange.location>selectRange.location) {
        NSRange tmp = lineRange;
        lineRange = selectRange;
        selectRange = tmp;
    }
    if (selectRange.location<lineRange.location+lineRange.length) {
        range.location = selectRange.location;
        NSUInteger end = MIN(selectRange.location+selectRange.length, lineRange.location+lineRange.length);
        range.length = end-range.location;
    }
    return range;
}
@end
