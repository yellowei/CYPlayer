//
//  CYVideoPlayerRegistrar.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/12/5.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerRegistrar.h"
#import <AVFoundation/AVFoundation.h>

@interface CYVideoPlayerRegistrar ()

@property (nonatomic, assign, readwrite) CYVideoPlayerBackstageState state;

@end

@implementation CYVideoPlayerRegistrar

- (instancetype)init {
    self = [super init];
    if ( !self ) return nil;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionRouteChangeNotification:) name:AVAudioSessionRouteChangeNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActiveNotification) name:UIApplicationWillResignActiveNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActiveNotification) name:UIApplicationDidBecomeActiveNotification object:nil];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)audioSessionRouteChangeNotification:(NSNotification*)notifi {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *interuptionDict = notifi.userInfo;
        NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
        switch (routeChangeReason) {
            case AVAudioSessionRouteChangeReasonNewDeviceAvailable: {
                if ( _newDeviceAvailable ) _newDeviceAvailable(self);
            }
                break;
            case AVAudioSessionRouteChangeReasonOldDeviceUnavailable: {
                if ( _oldDeviceUnavailable ) _oldDeviceUnavailable(self);
            }
                break;
            case AVAudioSessionRouteChangeReasonCategoryChange: {
                if ( _categoryChange ) _categoryChange(self);
            }
                break;
        }
    });
}

- (void)applicationWillResignActiveNotification {
    self.state = CYVideoPlayerBackstageState_Forground;
    if ( _willResignActive ) _willResignActive(self);
}

- (void)applicationDidBecomeActiveNotification {
    self.state = CYVideoPlayerBackstageState_Background;
    if ( _didBecomeActive ) _didBecomeActive(self);
}

@end
