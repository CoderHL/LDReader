//
//  UIImage+LDExtension.m
//  LDReader
//
//  Created by 刘洪 on 2018/11/19.
//  Copyright © 2018年 刘洪. All rights reserved.
//

#import "UIImage+LDExtension.h"

@implementation UIImage (LDExtension)

+ (UIImage *)stretchedImageWithPath:(NSString *)path{
    
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    int leftCap = image.size.width * 0.5;
    int topCap = image.size.height * 0.5;
    return [image stretchableImageWithLeftCapWidth:leftCap topCapHeight:topCap];
}

@end
