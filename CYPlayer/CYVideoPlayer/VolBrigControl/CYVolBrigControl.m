//
//  CYVolBrigControl.m
//  CYVolBrigControl
//
//  Created by yellowei on 2017/12/10.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVolBrigControl.h"
#import <MediaPlayer/MPVolumeView.h>
#import "CYVideoPlayerTipsView.h"
#import "CYVideoPlayerResources.h"
#import <AVFoundation/AVFoundation.h>

@interface CYVolBrigControl ()

@property (nonatomic, strong, readwrite) CYVideoPlayerTipsView *brightnessView;
@property (nonatomic, strong, readonly) UISlider *systemVolume;

@end

@implementation CYVolBrigControl
@synthesize systemVolume = _systemVolume;
@synthesize volume = _volume;

- (instancetype)init {
    self = [super init];
    if ( !self ) return nil;
    
    [self systemVolume];
    [self brightnessView];
    
    [[AVAudioSession sharedInstance] addObserver:self forKeyPath:@"outputVolume" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:(void *)[AVAudioSession sharedInstance]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenBrightnessDidChangeNotification:) name:UIScreenBrightnessDidChangeNotification object:nil];
    

    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    if( context == (__bridge void *)[AVAudioSession sharedInstance] ){
        float newValue = [[change objectForKey:@"new"] floatValue];
        if ( _volumeChanged ) _volumeChanged(newValue);
    }
}

- (void)dealloc {
    [[AVAudioSession sharedInstance] removeObserver:self forKeyPath:@"outputVolume"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (CYVideoPlayerTipsView *)brightnessView {
    if ( !_brightnessView ) {
        _brightnessView = [CYVideoPlayerTipsView new];
        _brightnessView.titleLabel.text = @"亮度";
        _brightnessView.normalShowImage = [CYVideoPlayerResources imageNamed:@"cy_video_player_brightness"];
    }
    _brightnessView.value = self.brightness;
    return _brightnessView;
}

- (UISlider *)systemVolume {
    if ( _systemVolume ) return _systemVolume;
    MPVolumeView *volumeView = [[MPVolumeView alloc] init];
    for (UIView *view in [volumeView subviews]){
//    [[UIApplication sharedApplication].keyWindow addSubview:volumeView]; // 隐藏系统volume
//    volumeView.frame = CGRectMake(-1000, -100, 100, 100);
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
            _systemVolume = (UISlider *)view;
            AVAudioSession *audioSession = [AVAudioSession sharedInstance];
            CGFloat currentVol = audioSession.outputVolume;
            _volume = currentVol;
//            _systemVolume.value  = currentVol;
            break;
        }
    }
    return _systemVolume;
}

- (void)setVolume:(float)volume {
    if (volume < 0)
    {
        volume = 0;
    }
    else if (volume > 1.0)
    {
        volume = 1.0;
    }
    
    if ( isnan(volume) ) volume = 0.0;
    
    _volume = volume;
    _systemVolume.value = volume;
}

- (void)setBrightness:(float)brightness {
    if ( isnan(brightness) )
    {
        brightness = 0;
        
    }
    if ( brightness < 0.1 )
    {
        brightness = 0.1;
    }
    else if ( brightness > 1 )
    {
        brightness = 1;
    }
    [UIScreen mainScreen].brightness = brightness;
    _brightnessView.value = brightness;
    if ( _brightnessChanged )
    {
        _brightnessChanged(brightness);
    }
}

- (float)brightness {
    return [UIScreen mainScreen].brightness;
}

- (void)screenBrightnessDidChangeNotification:(NSNotification *)notifi {
//    if ( _brightnessChanged ) _brightnessChanged([UIScreen mainScreen].brightness);
}

@end
