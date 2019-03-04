//
//  LSYMagnifierView.m
//  LSYReader
//
//  Created by Labanotation on 16/6/12.
//  Copyright © 2016年 okwei. All rights reserved.
//

#import "LDMagnifierView.h"

@implementation LDMagnifierView

- (id)initWithFrame:(CGRect)frame {
    
    if (self = [super initWithFrame:CGRectMake(0, 0, 100, 100)]) {
        self.layer.borderColor = [[UIColor lightGrayColor] CGColor];
        [self setBackgroundColor:[UIColor whiteColor]];
        self.layer.borderWidth = 1;
        self.layer.cornerRadius = 50;
        self.layer.masksToBounds = YES;
    }
    return self;
}
- (void)setTouchPoint:(CGPoint)touchPoint {
    
    _touchPoint = touchPoint;
//    NSLog(@"%@",NSStringFromCGPoint(touchPoint));
//    if (touchPoint.y<80) {
//        self.center = CGPointMake(touchPoint.x, touchPoint.y + 200);
//    }else{
    self.center = CGPointMake(touchPoint.x, touchPoint.y-30);
//    }
    [self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect {
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, self.frame.size.width*0.5,self.frame.size.height*0.5);
    CGContextScaleCTM(context, 1.0, 1.0);
    
    CGContextTranslateCTM(context, -1 * (_touchPoint.x), -1 * (_touchPoint.y+20));
    [self.readView.layer renderInContext:context];
}

@end
