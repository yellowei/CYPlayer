//
//  CYMoreSettingsFooterViewModel.h
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/12/5.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CYMoreSettingsFooterViewModel : NSObject

@property (nonatomic, copy) float(^initialVolumeValue)(void);
@property (nonatomic, copy) float(^initialBrightnessValue)(void);
@property (nonatomic, copy) float(^initialPlayerRateValue)(void);

@property (nonatomic, copy) void(^volumeChanged)(float volume);
@property (nonatomic, copy) void(^brightnessChanged)(float brightness);
@property (nonatomic, copy) void(^playerRateChanged)(float rate);

@property (nonatomic, copy) void(^needChangeVolume)(float volume);
@property (nonatomic, copy) void(^needChangeBrightness)(float brightness);
@property (nonatomic, copy) void(^needChangePlayerRate)(float rate);

@end
