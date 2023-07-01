//
//  CYAudioManager.h
//  cyplayer
//
//  Created by yellowei on 23.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/yellowei/cyplayer
//  this file is part of CYPlayer
//  CYPlayer is licenced under the LGPL v3, see lgpl-3.0.txt


//#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

@class CYAudioManager;

typedef void (^CYAudioManagerOutputBlock)(float *data, UInt32 numFrames, UInt32 numChannels);

@protocol CYAudioManagerDelegate <NSObject>


@end


@protocol CYAudioManager <NSObject>

@property (readonly) UInt32             numOutputChannels;
@property (readonly) Float64            samplingRate;
@property (readonly) UInt32             numBytesPerSample;
@property (readonly) Float32            outputVolume;
@property (readonly) BOOL               playing;
@property (readonly, strong) NSString   *audioRoute;

@property (readwrite, copy) CYAudioManagerOutputBlock outputBlock;

/**
 *资源原有属性, 重采样时使用,
 *原资源采样率过低(例如8000->44100)会造成视频音频同步困难
 */
@property (nonatomic, readwrite) NSInteger          avcodecContextNumOutputChannels;
@property (nonatomic, readwrite) double             avcodecContextSamplingRate;

@property (nonatomic, weak) id<CYAudioManagerDelegate> delegate;

- (BOOL) activateAudioSession;
- (void) deactivateAudioSession;
- (BOOL) play;
- (void) pause;

@end



@interface CYAudioManager : NSObject
+ (id<CYAudioManager>) audioManager;
@end
