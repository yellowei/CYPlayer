//
//  CYMoreSettingsFooterViewModel.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/12/5.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYMoreSettingsFooterViewModel.h"
#import <AVFoundation/AVPlayer.h>

@interface CYMoreSettingsFooterViewModel ()

@end

@implementation CYMoreSettingsFooterViewModel

- (instancetype)initWithAVPlayer:(AVPlayer *__weak)player {
    self = [super init];
    if ( !self ) return nil;
    return self;
}

@end
