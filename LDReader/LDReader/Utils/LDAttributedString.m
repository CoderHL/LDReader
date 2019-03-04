//
//  LDAttributedString.m
//  LDReader
//
//  Created by mengminduan on 2017/12/20.
//  Copyright © 2017年 mengminduan. All rights reserved.
//

#import "LDAttributedString.h"
#import "DTCoreText.h"

@interface LDAttributedString () <NSCoding>
{
    LDConfiguration *_configuration;
}
@property (nonatomic, strong) NSMutableArray *attrArray;
@property (nonatomic, strong) NSString *string;
@property (nonatomic, strong) NSMutableArray *spaceRangeArray;

@end
extern UIColor *_preTextColor; //设置当前文本颜色
@implementation LDAttributedString

- (instancetype)initWithAttributedString:(NSAttributedString *)attrString
{
    if (self = [super init]) {
        self.string = attrString.string;
        self.attrArray = [NSMutableArray array];
        self.spaceRangeArray = [NSMutableArray array];
        [attrString enumerateAttributesInRange:NSMakeRange(0, attrString.length) options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired usingBlock:^(NSDictionary<NSAttributedStringKey, id> *attrs, NSRange range, BOOL *stop) {

            if ([[attrs allKeys] containsObject:(id)kCTRunDelegateAttributeName]) {
                [self.spaceRangeArray addObject:[NSValue valueWithRange:range]];
            }else {
                NSDictionary *newAttr = @{
                                          @"attr":attrs,
                                          @"range":[NSValue valueWithRange:range]
                                          };
                [self.attrArray addObject:newAttr];
            }
        }];
    }
    return self;
}

- (NSAttributedString *)convertToAttributedString:(LDConfiguration *)configuration
{
    _configuration = configuration;
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:self.string];
    for (NSDictionary *dict in self.attrArray) {
        NSDictionary *attr = [dict objectForKey:@"attr"];
        NSRange range = [[dict objectForKey:@"range"] rangeValue];
        [attrString addAttributes:attr range:range];
    }
    NSString *test = @"哈哈";
    UIFont *font = [UIFont fontWithName:configuration.fontName size:configuration.fontSize];
    CGSize testSize = [test boundingRectWithSize:CGSizeMake(100, CGFLOAT_MAX)
                                         options:NSStringDrawingUsesFontLeading | NSStringDrawingUsesLineFragmentOrigin
                                      attributes:@{NSFontAttributeName:font}
                                         context:nil].size;
    for (NSValue *value in self.spaceRangeArray) {
        NSRange spaceRange = [value rangeValue];
        DTTextAttachment *attachment = [[DTTextAttachment alloc] init];
        attachment.displaySize = CGSizeMake(testSize.width, 20);
        NSMutableDictionary *newAttributes = [NSMutableDictionary new];
        [newAttributes setObject:attachment forKey:NSAttachmentAttributeName];
        CTRunDelegateRef embeddedObjectRunDelegate = createEmbeddedObjectRunDelegate((id)attachment);
        [newAttributes setObject:(__bridge id)embeddedObjectRunDelegate forKey:(id)kCTRunDelegateAttributeName];
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init];
        paragraphStyle.alignment = NSTextAlignmentJustified;
        paragraphStyle.lineSpacing = configuration.lineSpacing;
        paragraphStyle.paragraphSpacing = configuration.lineSpacing*2;
        [newAttributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
        [attrString addAttributes:newAttributes range:spaceRange];
        CFRelease(embeddedObjectRunDelegate);
    }
    return attrString;
}


- (NSAttributedString *)autoReserveModeColorWithAttributeString:(NSAttributedString *)attributeStr
{
    if (_preTextColor && ![_preTextColor isEqual:_configuration.textColor] && _configuration.textColor) {
        NSMutableAttributedString *mutableAttr = [[NSMutableAttributedString alloc]initWithAttributedString:attributeStr];
        [mutableAttr enumerateAttributesInRange:NSMakeRange(0, attributeStr.length) options:NSAttributedStringEnumerationReverse usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
            //foregroundColor
            UIColor *cgColor = [attrs objectForKey:@"NSColor"];
            if (cgColor) {
                [mutableAttr addAttribute:@"NSColor" value:_configuration.textColor range:range];
            }
        }];
        return mutableAttr;
    }else{
        return nil;
    }
}

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
    [aCoder encodeObject:self.attrArray forKey:@"attrArray"];
    [aCoder encodeObject:self.string forKey:@"string"];
    [aCoder encodeObject:self.spaceRangeArray forKey:@"spaceRange"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder {
    
    if (self = [super init]) {
        self.attrArray = [aDecoder decodeObjectForKey:@"attrArray"];
        self.string = [aDecoder decodeObjectForKey:@"string"];
        self.spaceRangeArray = [aDecoder decodeObjectForKey:@"spaceRange"];
    }
    return self;
}

@end
