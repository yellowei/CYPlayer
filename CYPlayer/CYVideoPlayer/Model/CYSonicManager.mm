//
//  CYSonicManager.m
//  CYPlayer
//
//  Created by 杨倩 on 2020/6/22.
//  Copyright © 2020 Sutan. All rights reserved.
//

#import "CYSonicManager.h"
#import "sonic.h"
#import "CYAudioManager.h"
#import <AVFoundation/AVFoundation.h>

@interface CYSonicManager()
{
    sonicStream stream;
}
@end

@implementation CYSonicManager

+ (CYSonicManager *) sonicManager
{
    static CYSonicManager *sonicManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sonicManager = [[CYSonicManager alloc] init];
    });
    return sonicManager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        NSInteger channels = [AVAudioSession sharedInstance].outputNumberOfChannels;
        double sampleRate = [AVAudioSession sharedInstance].sampleRate;
        stream = sonicCreateStream((int)(sampleRate), (int)(channels));
        sonicSetSpeed(stream, 1.0);
        sonicSetPitch(stream, 1.0);
        sonicSetVolume(stream, 1.0);
        sonicSetRate(stream, 1.0);
        self.playSpeed = 1.0;
    }
    return self;
}


- (NSData *)setFloatData:(NSData *)data{
    
    NSMutableData *sonicdDatas = [[NSMutableData alloc] init];
    int lenBytes = (int)data.length;
    float * dataBytes = (float *)[data bytes];
    float * outBytes = (float *)malloc(lenBytes);

    int samples = lenBytes/(sizeof(float)* sonicGetNumChannels(stream));
    int ret = sonicWriteFloatToStream(stream, dataBytes, samples);
    if (ret) {
        int available = sonicSamplesAvailable(stream) * sizeof(float) * sonicGetNumChannels(stream);
        if (lenBytes > available) {
            lenBytes = available;
        }
        outBytes = (float *)realloc(outBytes, lenBytes);
            
        int samplesRead;
        do {
            samplesRead = sonicReadFloatFromStream(stream, outBytes, lenBytes/(sizeof(float)*sonicGetNumChannels(stream)));
            if (samplesRead > 0) {
                int bytesRead = samplesRead * sizeof(float) * sonicGetNumChannels(stream);
                [sonicdDatas appendBytes:outBytes length:bytesRead];
            }
        } while (samplesRead > 0);
    }
    free(outBytes);
    return sonicdDatas;
}


- (NSData *)setShortData:(NSData *)data{
    
    NSMutableData *sonicdDatas = [[NSMutableData alloc] init];
    int lenBytes = (int)data.length;
    short * dataBytes = (short *)[data bytes];
    short * outBytes = (short *)malloc(lenBytes);

    int samples = lenBytes/(sizeof(short)* sonicGetNumChannels(stream));
    int ret = sonicWriteShortToStream(stream, dataBytes, samples);
    if (ret) {
        int available = sonicSamplesAvailable(stream) * sizeof(short) * sonicGetNumChannels(stream);
        if (lenBytes > available) {
            lenBytes = available;
        }
        outBytes = (short *)realloc(outBytes, lenBytes);

        int samplesRead;
        do {
            samplesRead = sonicReadShortFromStream(stream, outBytes, lenBytes/(sizeof(short)*sonicGetNumChannels(stream)));
            if (samplesRead > 0) {
                int bytesRead = samplesRead * sizeof(short) * sonicGetNumChannels(stream);
                [sonicdDatas appendBytes:outBytes length:bytesRead];
            }
        } while (samplesRead > 0);
    }
    return sonicdDatas;
}


- (void)setPlayRate:(double)playRate{
    
    _playRate = playRate;
    sonicSetSpeed(stream, playRate);
}

- (void)setPlaySpeed:(double)playSpeed{
    _playSpeed = playSpeed;
    sonicSetSpeed(stream, playSpeed);
}


- (void)destroySonic{
    
    sonicDestroyStream(stream);
    stream = NULL;
}

@end
