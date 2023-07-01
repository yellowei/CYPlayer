//
//  CYVideoPlayerSettings.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/9/25.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerSettings.h"

NSNotificationName const CYSettingsPlayerNotification = @"CYSettingsPlayerNotification";

@implementation CYVideoPlayerSettings

+ (instancetype)sharedVideoPlayerSettings
{
    static id _instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

@end
