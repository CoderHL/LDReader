//
//  LDPageModel.m
//  LDReader
//
//  Created by mengminduan on 2017/10/11.
//  Copyright © 2017年 mengminduan. All rights reserved.
//

#import "LDPageModel.h"

@interface LDPageModel () <NSCoding>

@end
@implementation LDPageModel

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
    NSValue *rangeValue = [NSValue valueWithRange:self.range];
    [aCoder encodeObject:rangeValue forKey:@"range"];
    [aCoder encodeObject:self.attrString forKey:@"attrString"];
    [aCoder encodeObject:self.pageString forKey:@"pageString"];
    [aCoder encodeObject:@(self.lastPage) forKey:@"lastPage"];
    [aCoder encodeObject:@(self.pageIndex) forKey:@"pageIndex"];
    [aCoder encodeObject:self.markArray forKey:@"markArray"];
    [aCoder encodeObject:@(self.chapterIndex) forKey:@"chapterIndex"];
    [aCoder encodeObject:@(self.advertising) forKey:@"advertising"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder {
    if (self = [super init]) {
        self.attrString = [aDecoder decodeObjectForKey:@"attrString"];
        self.pageString = [aDecoder decodeObjectForKey:@"pageString"];
        NSValue *rangeValue = [aDecoder decodeObjectForKey:@"range"];
        self.range = [rangeValue rangeValue];
        NSNumber *lastPageN = [aDecoder decodeObjectForKey:@"lastPage"];
        self.lastPage = [lastPageN integerValue];
        NSNumber *pageIndexN = [aDecoder decodeObjectForKey:@"pageIndex"];
        self.pageIndex = [pageIndexN integerValue];
        self.markArray = [aDecoder decodeObjectForKey:@"markArray"];
        self.chapterIndex = [[aDecoder decodeObjectForKey:@"chapterIndex"] integerValue];
        self.advertising = [[aDecoder decodeObjectForKey:@"advertising"] boolValue];
    }
    return self;
}

-(NSMutableArray *)markArray
{
    if (!_markArray) {
        _markArray = [NSMutableArray array];
    }
    return _markArray;
}

@end
