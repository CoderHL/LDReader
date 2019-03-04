//
//  UIView+LDExtension.m
//  LDTxtReader
//
//  Created by 刘洪 on 2017/10/11.
//  Copyright © 2017年 刘洪. All rights reserved.
//

#import "UIView+LDExtension.h"

@implementation UIView (LDExtension)
- (void)setLd_x:(CGFloat)ld_x
{
    CGRect frame = self.frame;
    frame.origin.x = ld_x;
    self.frame = frame;
}


- (void)setLd_y:(CGFloat)ld_y
{
    CGRect frame = self.frame;
    frame.origin.y = ld_y;
    self.frame = frame;
}

- (CGFloat)ld_x
{
    return self.frame.origin.x;
}

- (CGFloat)ld_y
{
    return self.frame.origin.y;
}

- (void)setLd_centerX:(CGFloat)ld_centerX
{
    CGPoint center = self.center;
    center.x = ld_centerX;
    self.center = center;
}

- (CGFloat)ld_centerX
{
    return self.center.x;
}

- (void)setLd_centerY:(CGFloat)ld_centerY
{
    CGPoint center = self.center;
    center.y = ld_centerY;
    self.center = center;
}

- (CGFloat)ld_centerY
{
    return self.center.y;
}

- (void)setLd_width:(CGFloat)ld_width
{
    CGRect frame = self.frame;
    frame.size.width = ld_width;
    self.frame = frame;
}


- (void)setLd_height:(CGFloat)ld_height
{
    CGRect frame = self.frame;
    frame.size.height = ld_height;
    self.frame = frame;
}

- (CGFloat)ld_height
{
    return self.frame.size.height;
}

- (CGFloat)ld_width
{
    
    return self.frame.size.width;
}

- (void)setLd_size:(CGSize)ld_size
{
    CGRect frame = self.frame;
    frame.size = ld_size;
    self.frame = frame;
}

- (CGSize)ld_size
{
    return self.frame.size;
}

- (void)setLd_origin:(CGPoint)ld_origin
{
    
    CGRect frame = self.frame;
    frame.origin = ld_origin;
    self.frame = frame;
}

- (CGPoint)ld_origin
{
    return self.frame.origin;
}

@end
