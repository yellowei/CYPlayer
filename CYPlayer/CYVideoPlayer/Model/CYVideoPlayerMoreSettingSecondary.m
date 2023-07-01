//
//  CYVideoPlayerMoreSettingSecondary.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/12/5.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerMoreSettingSecondary.h"
#import <objc/message.h>

@implementation CYVideoPlayerMoreSettingSecondary

+ (void)setTopTitleFontSize:(float)topTitleFontSize {
    objc_setAssociatedObject(self, @selector(topTitleFontSize), @(topTitleFontSize), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (float)topTitleFontSize {
    float fontSize = [objc_getAssociatedObject(self, _cmd) floatValue];
    if ( 0 != fontSize ) return fontSize;
    fontSize = 14;
    [self setTopTitleFontSize:fontSize];
    return fontSize;
}

@end
