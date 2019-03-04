//
//  LDPageViewController.m
//  LDReader
//
//  Created by mengminduan on 2017/10/11.
//  Copyright © 2017年 mengminduan. All rights reserved.
//

#import "LDPageViewController.h"

@interface LDPageViewController ()
@end

@implementation LDPageViewController

static UIColor *backgroundColor;
static UIImage *backgroundImage;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (!backgroundImage && !backgroundColor) {
        self.view.backgroundColor = [UIColor whiteColor];
    }else if (backgroundImage) {
        [self.backgroundImageView removeFromSuperview];
        self.backgroundImageView = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.ld_x, self.view.ld_y, self.view.ld_width, self.view.ld_height)];
        self.backgroundImageView.image = backgroundImage;
        [self.view addSubview:self.backgroundImageView];
    }else if (backgroundColor) {
        [self.backgroundImageView removeFromSuperview];
        self.backgroundImageView = nil;
        self.view.backgroundColor = backgroundColor;
    }
}

+ (void)setBackGround:(BOOL)isImage configuration:(LDConfiguration *)configuration
{
    if (isImage) {
        if (!configuration.backgroundImage) {
            return;
        }
        backgroundImage = configuration.backgroundImage;
        backgroundColor = nil;
    }else {
        if (!configuration.backgroundColor) {
            return;
        }
        backgroundColor = configuration.backgroundColor;
        backgroundImage = nil;
    }
}

@end
