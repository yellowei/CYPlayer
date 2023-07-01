//
//  CYOpenALPlayer.h
//  CYPlayer
//
//  Created by 黄威 on 2018/8/31.
//  Copyright © 2018年 Sutan. All rights reserved.
//

//#define USE_OLD @"USE_OLD"
#ifdef USE_OLD
#import <Foundation/Foundation.h>
#import <OpenAL/al.h>
#import <OpenAL/alc.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/ExtendedAudioFile.h>

@interface CYOpenALPlayer : NSObject
{
    ALCcontext *mContext;
    ALCdevice *mDevice;
    ALuint outSourceID;
    
    NSMutableDictionary* soundDictionary;
    NSMutableArray* bufferStorageArray;
    
    ALuint buff;
    NSTimer* updateBufferTimer;
    
    ALenum audioFormat;
    int sampleRate;
}
@property (nonatomic)ALenum audioFormat;
@property (nonatomic)ALCcontext *mContext;
@property (nonatomic)ALCdevice *mDevice;
@property (nonatomic, assign) ALuint outSourceID;
@property (nonatomic,retain)NSMutableDictionary* soundDictionary;
@property (nonatomic,retain)NSMutableArray* bufferStorageArray;

- (BOOL)isPlaying;
- (void)initOpenAL:(int)format :(int)sampleRate;
- (void)openAudioFromQueue:(unsigned char *)dataBuffer withLength: (int)length;
- (void)playSound;
- (void)playSound:(NSString*)soundKey;
//如果声音不循环,那么它将会自然停止。如果是循环的,你需要停止
- (void)stopSound;
- (void)stopSound:(NSString*)soundKey;

- (void)cleanUpOpenAL;
- (void)cleanUpOpenAL:(id)sender;
@end

#else
#import <Foundation/Foundation.h>
#import<Openal/Openal.h>

@interface CYOpenALPlayer : NSObject
@property(nonatomic,assign)int m_numprocessed;             //队列中已经播放过的数量
@property(nonatomic,assign) int m_numqueued;                //队列中缓冲队列数量
@property(nonatomic,assign) long long m_IsplayBufferSize;   //已经播放了多少个音频缓存数目
@property(nonatomic,assign) double m_oneframeduration;      //一帧音频数据持续时间(ms)
@property(nonatomic,assign) float m_volume;                 //当前音量volume取值范围(0~1)
@property(nonatomic,assign) int m_samplerate;               //采样率
@property(nonatomic,assign) int m_bit;                      //样本值
@property(nonatomic,assign) int m_channel;                  //声道数
@property(nonatomic,assign) int m_datasize;                 //一帧音频数据量
@property(nonatomic,assign) double playRate;                //播放速率

#pragma mark - 接口
- (BOOL)isPlaying;
-(int)initOpenAL;
-(int)updataQueueBuffer;
- (void)clearBuffer;
-(void)cleanUpOpenAL;
-(void)playSound;
-(void)stopSound;
-(int)openAudioFromQueue:(char*)data andWithDataSize:(int)dataSize andWithSampleRate:(int) aSampleRate andWithAbit:(int)aBit andWithAchannel:(int)aChannel;
@end

#endif
