//
//  LDReaderBook.h
//  LDTxtReader
//
//  Created by 刘洪 on 2017/10/12.
//  Copyright © 2017年 刘洪. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LDBookModel : NSObject

@property (nonatomic, strong, nonnull) NSString *name;
@property (nonatomic, strong, nonnull) NSString *author;
@property (nonatomic, strong, nonnull) UIImage *coverImage;
@property (nonatomic, strong, nullable) NSString *copyright;//版权

@end
