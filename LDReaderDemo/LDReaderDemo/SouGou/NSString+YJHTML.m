//
//  NSString+YJHTML.m
//  LDReaderDemo
//
//  Created by 刘洪 on 2018/12/3.
//  Copyright © 2018年 刘洪. All rights reserved.
//

#import "NSString+YJHTML.h"
#import "YJNSString+HTML.h"

@implementation NSString (YJHTML)

#pragma mark -
#pragma mark Class Methods

#pragma mark -
#pragma mark Instance Methods

// Strip HTML tags
- (NSString *)stringByConvertingHTMLToPlainText {
    
    // Pool
	
	// Character sets
	NSCharacterSet *stopCharacters = [NSCharacterSet characterSetWithCharactersInString:[NSString stringWithFormat:@"< \t\n\r%C%C%C%C", 0x0085, 0x000C, 0x2028, 0x2029]];
	NSCharacterSet *newLineAndWhitespaceCharacters = [NSCharacterSet characterSetWithCharactersInString:[NSString stringWithFormat:@" \t\n\r%C%C%C%C", 0x0085, 0x000C, 0x2028, 0x2029]];
	NSCharacterSet *tagNameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"]; /**/
	
	// Scan and find all tags
	NSMutableString *result = [[NSMutableString alloc] initWithCapacity:self.length];
	NSScanner *scanner = [[NSScanner alloc] initWithString:self];
	[scanner setCharactersToBeSkipped:nil];
	[scanner setCaseSensitive:YES];
	NSString *str = nil, *tagName = nil;
	BOOL dontReplaceTagWithSpace = NO;
	do {
		
		// Scan up to the start of a tag or whitespace
		if ([scanner scanUpToCharactersFromSet:stopCharacters intoString:&str]) {
			[result appendString:str];
			str = nil; // reset
		}
        
		
		// Check if we've stopped at a tag/comment or whitespace
		if ([scanner scanString:@"<" intoString:NULL]) {
            
			
			// Stopped at a comment or tag
			if ([scanner scanString:@"!--" intoString:NULL]) {
				
				// Comment
				[scanner scanUpToString:@"-->" intoString:NULL];
                
				[scanner scanString:@"-->" intoString:NULL];
           
			} else {
				
				// Tag - remove and replace with space unless it's
                if ([scanner scanString:@"/p>" intoString:NULL] ||
                    [scanner scanString:@"/P>" intoString:NULL]) {
                    [result appendString:@"\n\n"];
                    [result appendString:@"    "];
                }
                if ([scanner scanString:@"/div>" intoString:NULL] ||
                    [scanner scanString:@"/DIV>" intoString:NULL]) {
                    [result appendString:@"\n"];
                    [result appendString:@"    "];
                }
                if ([scanner scanString:@"/h1" intoString:NULL] ||
                    [scanner scanString:@"/h2" intoString:NULL] ||
                    [scanner scanString:@"/h3" intoString:NULL] ||
                    [scanner scanString:@"/h4" intoString:NULL] ||
                    [scanner scanString:@"/h5" intoString:NULL] ||
                    [scanner scanString:@"/H1" intoString:NULL] ||
                    [scanner scanString:@"/H2" intoString:NULL] ||
                    [scanner scanString:@"/H3" intoString:NULL] ||
                    [scanner scanString:@"/H4" intoString:NULL] ||
                    [scanner scanString:@"/H5" intoString:NULL]) {
                    [result appendString:@"\n\n"];
                    [result appendString:@"    "];
                }
                
                if ([scanner scanString:@"img" intoString:NULL]) {
                    [scanner scanUpToString:@"src" intoString:NULL];
                    [scanner scanString:@"src" intoString:NULL];
                    [scanner scanString:@"=" intoString:NULL];
                    [scanner scanString:@"\'" intoString:NULL];
                    [scanner scanString:@"\"" intoString:NULL];
                    NSString *imgString;
                    if ([scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"\'"] intoString:&imgString]) {
                        [result appendString:[NSString stringWithFormat:@"\n<img>%@</img>\n",imgString]];
                        imgString = nil; // reset
                    }
                    
                }
                if ([scanner scanString:@"BR" intoString:NULL] ||
                    [scanner scanString:@"br" intoString:NULL]) {
                    
                    [result appendString:[NSString stringWithFormat:@"\n"]];
                    [result appendString:@"    "];
                }
                if ([scanner scanString:@"title" intoString:NULL]) {
                    [scanner scanUpToString:@"</title>" intoString:NULL];
                    [scanner scanString:@"</title>" intoString:NULL];
                }
				// a closing inline tag then dont replace with a space
				if ([scanner scanString:@"/" intoString:NULL]) {
                    
					
					// Closing tag - replace with space unless it's inline
					tagName = nil; dontReplaceTagWithSpace = NO;
					if ([scanner scanCharactersFromSet:tagNameCharacters intoString:&tagName]) {
						tagName = [tagName lowercaseString];
						dontReplaceTagWithSpace = ([tagName isEqualToString:@"a"] ||
												   [tagName isEqualToString:@"b"] ||
												   [tagName isEqualToString:@"i"] ||
												   [tagName isEqualToString:@"q"] ||
												   [tagName isEqualToString:@"span"] ||
												   [tagName isEqualToString:@"em"] ||
												   [tagName isEqualToString:@"strong"] ||
												   [tagName isEqualToString:@"cite"] ||
												   [tagName isEqualToString:@"abbr"] ||
												   [tagName isEqualToString:@"acronym"] ||
												   [tagName isEqualToString:@"label"]);
					}
					
					// Replace tag with string unless it was an inline
					if (!dontReplaceTagWithSpace && result.length > 0 && ![scanner isAtEnd]) [result appendString:@" "];
					
				}
				
				// Scan past tag
				[scanner scanUpToString:@">" intoString:NULL];
                
				[scanner scanString:@">" intoString:NULL];
				
			}
			
		} else {
			
			// Stopped at whitespace - replace all whitespace and newlines with a space
			if ([scanner scanCharactersFromSet:newLineAndWhitespaceCharacters intoString:NULL]) {
				if (result.length > 0 && ![scanner isAtEnd]) [result appendString:@" "]; // Dont append space to beginning or end of result
			}
			
		}
		
	} while (![scanner isAtEnd]);
	
	// Cleanup

	
	// Decode HTML entities and return
	NSString *retString = [result stringByDecodingHTMLEntities];
    
    retString = [retString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	// Return
	return retString;
	
}

- (NSString *)deleteStyle {
    NSMutableString *muStr = [self mutableCopy];
    
    NSError *error;
    // 创建NSRegularExpression对象并指定正则表达式
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"(<style)([^<]*)(</style>)"
                                  options:0
                                  error:&error];
    if (!error) { // 如果没有错误
        // 获取特特定字符串的范围
        NSTextCheckingResult *match = [regex firstMatchInString:muStr
                                                        options:0
                                                          range:NSMakeRange(0, [muStr length])];
        if (match) {
            // 截获特定的字符串
            NSString *result = [muStr substringWithRange:match.range];
            NSRange range = [muStr rangeOfString:result];
            [muStr replaceCharactersInRange:range withString:@""];
            //            NSLog(@"%@",result);
        }
    } else { // 如果有错误，则把错误打印出来
        NSLog(@"error - %@", error);
    }
    return [muStr copy];
}

// Decode all HTML entities using YJ
- (NSString *)stringByDecodingHTMLEntities {
	// gtm_stringByUnescapingFromHTML can return self so create new string ;)
	return [NSString stringWithString:[self gtm_stringByUnescapingFromHTML]]; 
}

// Encode all HTML entities using YJ
- (NSString *)stringByEncodingHTMLEntities {
	// gtm_stringByUnescapingFromHTML can return self so create new string ;)
	return [NSString stringWithString:[self gtm_stringByEscapingForAsciiHTML]];
}

// Replace newlines with <br /> tags
- (NSString *)stringWithNewLinesAsBRs {
	
	// Pool
	
	// Strange New lines:
	//	Next Line, U+0085
	//	Form Feed, U+000C
	//	Line Separator, U+2028
	//	Paragraph Separator, U+2029
	
	// Scanner
	NSScanner *scanner = [[NSScanner alloc] initWithString:self];
	[scanner setCharactersToBeSkipped:nil];
	NSMutableString *result = [[NSMutableString alloc] init];
	NSString *temp;
	NSCharacterSet *newLineCharacters = [NSCharacterSet characterSetWithCharactersInString:
										 [NSString stringWithFormat:@"\n\r%C%C%C%C", 0x0085, 0x000C, 0x2028, 0x2029]];
	// Scan
	do {
		
		// Get non new line characters
		temp = nil;
		[scanner scanUpToCharactersFromSet:newLineCharacters intoString:&temp];
		if (temp) [result appendString:temp];
		temp = nil;
		
		// Add <br /> s
		if ([scanner scanString:@"\r\n" intoString:nil]) {
			
			// Combine \r\n into just 1 <br />
			[result appendString:@"<br />"];
			
		} else if ([scanner scanCharactersFromSet:newLineCharacters intoString:&temp]) {
			
			// Scan other new line characters and add <br /> s
			if (temp) {
				for (int i = 0; i < temp.length; i++) {
					[result appendString:@"<br />"];
				}
			}
			
		}
		
	} while (![scanner isAtEnd]);
	
	// Cleanup & return

	NSString *retString = [NSString stringWithString:result];

	
	// Drain

	
	// Return
	return retString;
	
}

// Remove newlines and white space from strong
- (NSString *)stringByRemovingNewLinesAndWhitespace {
	
	// Pool
	
	// Strange New lines:
	//	Next Line, U+0085
	//	Form Feed, U+000C
	//	Line Separator, U+2028
	//	Paragraph Separator, U+2029
	
	// Scanner
	NSScanner *scanner = [[NSScanner alloc] initWithString:self];
	[scanner setCharactersToBeSkipped:nil];
	NSMutableString *result = [[NSMutableString alloc] init];
	NSString *temp;
	NSCharacterSet *newLineAndWhitespaceCharacters = [NSCharacterSet characterSetWithCharactersInString:
													  [NSString stringWithFormat:@" \t\n\r%C%C%C%C", 0x0085, 0x000C, 0x2028, 0x2029]];
	// Scan
	while (![scanner isAtEnd]) {
		
		// Get non new line or whitespace characters
		temp = nil;
		[scanner scanUpToCharactersFromSet:newLineAndWhitespaceCharacters intoString:&temp];
		if (temp) [result appendString:temp];
		
		// Replace with a space
		if ([scanner scanCharactersFromSet:newLineAndWhitespaceCharacters intoString:NULL]) {
			if (result.length > 0 && ![scanner isAtEnd]) // Dont append space to beginning or end of result
				[result appendString:@" "];
		}
		
	}
	
	// Cleanup

	
	// Return
	NSString *retString = [NSString stringWithString:result];

	
	// Drain

	
	// Return
	return retString ;
	
}

// Strip HTML tags
// DEPRECIATED - Please use NSString stringByConvertingHTMLToPlainText
- (NSString *)stringByStrippingTags {
	
	// Pool

	
	// Find first & and short-cut if we can
	NSUInteger ampIndex = [self rangeOfString:@"<" options:NSLiteralSearch].location;
	if (ampIndex == NSNotFound) {
		return [NSString stringWithString:self]; // return copy of string as no tags found
	}
	
	// Scan and find all tags
	NSScanner *scanner = [NSScanner scannerWithString:self];
	[scanner setCharactersToBeSkipped:nil];
	NSMutableSet *tags = [[NSMutableSet alloc] init];
	NSString *tag;
	do {
		
		// Scan up to <
		tag = nil;
		[scanner scanUpToString:@"<" intoString:NULL];
		[scanner scanUpToString:@">" intoString:&tag];
		
		// Add to set
		if (tag) {
			NSString *t = [[NSString alloc] initWithFormat:@"%@>", tag];
			[tags addObject:t];

		}
		
	} while (![scanner isAtEnd]);
	
	// Strings
	NSMutableString *result = [[NSMutableString alloc] initWithString:self];
	NSString *finalString;
	
	// Replace tags
	NSString *replacement;
	for (NSString *t in tags) {
		
		// Replace tag with space unless it's an inline element
		replacement = @" ";
		if ([t isEqualToString:@"<a>"] ||
			[t isEqualToString:@"</a>"] ||
			[t isEqualToString:@"<span>"] ||
			[t isEqualToString:@"</span>"] ||
			[t isEqualToString:@"<strong>"] ||
			[t isEqualToString:@"</strong>"] ||
			[t isEqualToString:@"<em>"] ||
			[t isEqualToString:@"</em>"]) {
			replacement = @"";
		}
		
		// Replace
		[result replaceOccurrencesOfString:t 
								withString:replacement
								   options:NSLiteralSearch 
									 range:NSMakeRange(0, result.length)];
	}
	
	// Remove multi-spaces and line breaks
	finalString = [result stringByRemovingNewLinesAndWhitespace];
	
	// Cleanup


	
	// Drain

	
	// Return
    return finalString ;
	
}

@end