//
//  LDUtil.m
//  LDReader
//
//  Created by mengminduan on 2017/10/19.
//  Copyright © 2017年 mengminduan. All rights reserved.
//

#import "LDUtil.h"

@implementation LDUtil

+ (NSString *)toString:(NSInteger)integer
{
    return [NSString stringWithFormat:@"%ld", (long)integer];
}

+ (UIImage *)imageFromViewController:(UIViewController *)viewController
{
    UIImage *image;
    CGRect rect = viewController.view.bounds;
    UIGraphicsBeginImageContextWithOptions(rect.size, YES, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [viewController.view.layer renderInContext:context];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
@end
