//
//  CYPromptConfig.m
//  CYPromptProject
//
//  Created by yellowei on 2017/12/14.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYPromptConfig.h"

@implementation CYPromptConfig

- (instancetype)init {
    self = [super init];
    if ( !self ) return nil;
    [self reset];
    return self;
}

- (void)reset {
    _insets = UIEdgeInsetsMake(8, 8, 8, 8);
    _cornerRadius = 8.0;
    _backgroundColor = [UIColor blackColor];
    _font = [UIFont systemFontOfSize:14];
    _fontColor = [UIColor whiteColor];
}

@end
