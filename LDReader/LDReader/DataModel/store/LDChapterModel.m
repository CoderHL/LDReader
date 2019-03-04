//
//  LDChapterModel.m
//  LDReader
//
//  Created by mengminduan on 2017/10/11.
//  Copyright © 2017年 mengminduan. All rights reserved.
//

#import "LDChapterModel.h"

@implementation LDChapterModel


- (void)encodeWithCoder:(NSCoder *)aCoder

{
        
    [aCoder encodeObject:_title forKey:@"title"];
    [aCoder encodeObject:_path forKey:@"path"];
    NSNumber *number1 = [NSNumber numberWithInteger:_commentCounts];
    [aCoder encodeObject:number1 forKey:@"commentCounts"];
    NSNumber *number2 = [NSNumber numberWithInteger:_chapterIndex];
    [aCoder encodeObject:number2 forKey:@"chapterIndex"];
  
}

- (id)initWithCoder:(NSCoder *)aDecoder

{
    
    if (self = [super init]) {
        
        self.title = [aDecoder decodeObjectForKey:@"title"];
        self.path = [aDecoder decodeObjectForKey:@"path"];
        NSNumber *number1 = [aDecoder decodeObjectForKey:@"commentCounts"];
        self.commentCounts = [number1 integerValue];
        NSNumber *number2 = [aDecoder decodeObjectForKey:@"chapterIndex"];
        self.chapterIndex = [number2 integerValue];
        
    }
    
    return self;
    
}

@end
