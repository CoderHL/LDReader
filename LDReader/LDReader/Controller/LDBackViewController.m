//
//  LDBackViewController.m
//  LDReader
//
//  Created by mengminduan on 2017/10/16.
//  Copyright © 2017年 mengminduan. All rights reserved.
//

#import "LDBackViewController.h"

@interface LDBackViewController ()
@property (nonatomic, strong) UIImage *backImage;
@end

@implementation LDBackViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.view.ld_width, self.view.ld_height)];
    imageView.image = self.backImage;
    [self.view addSubview:imageView];
}

- (void)grabViewController:(LDPageViewController *)viewController
{
    self.index = viewController.index;
    self.chapterBelong = viewController.chapterBelong;
    CGRect rect = viewController.view.bounds;
    UIGraphicsBeginImageContextWithOptions(rect.size, YES, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGAffineTransform transform = CGAffineTransformMake(-1.0, 0.0, 0.0, 1.0, rect.size.width, 0.0);
    CGContextConcatCTM(context, transform);
    [viewController.view.layer renderInContext:context];
    self.backImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
}


@end
