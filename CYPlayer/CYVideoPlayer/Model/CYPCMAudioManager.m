//
//  CYPCMAudioManager.m
//  CYPlayer
//
//  Created by 黄威 on 2018/8/24.
//  Copyright © 2018年 Sutan. All rights reserved.
//

#import "CYPCMAudioManager.h"
#import "CYOpenALPlayer.h"
#import <CYFFmpeg/CYFFmpeg.h>

typedef struct Wavehead
{
    /****RIFF WAVE CHUNK*/
    unsigned char a[4];     //四个字节存放'R','I','F','F'
    long int b;             //整个文件的长度-8;每个Chunk的size字段，都是表示除了本Chunk的ID和SIZE字段外的长度;
    unsigned char c[4];     //四个字节存放'W','A','V','E'
    /****RIFF WAVE CHUNK*/
    /****Format CHUNK*/
    unsigned char d[4];     //四个字节存放'f','m','t',''
    long int e;             //16后没有附加消息，18后有附加消息；一般为16，其他格式转来的话为18
    short int f;            //编码方式，一般为0x0001;
    short int g;            //声道数目，1单声道，2双声道;
    int h;                  //采样频率;
    unsigned int i;         //每秒所需字节数;
    short int j;            //每个采样需要多少字节，若声道是双，则两个一起考虑;
    short int k;            //即量化位数
    /****Format CHUNK*/
    /***Data Chunk**/
    unsigned char p[4];     //四个字节存放'd','a','t','a'
    long int q;             //语音数据部分长度，不包括文件头的任何部分
} WaveHead;//定义WAVE文件的文件头结构体

@interface CYPCMAudioManager()<AVAudioSessionDelegate>

@property (nonatomic,strong) NSMutableData *pcmData;
@property (nonatomic,strong) NSTimer *timer;

@end

@implementation CYPCMAudioManager

+ (CYPCMAudioManager*) audioManager
{
    static CYPCMAudioManager *audioManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        audioManager = [[CYPCMAudioManager alloc] init];
    });
    return audioManager;
}

- (instancetype)init
{
    if (self = [super init])
    {
        
    }
    return self;
}

-(void)setFilePath:(NSString *)path
{
    NSData * data = [NSData dataWithContentsOfFile:path];
    
    if (data == nil) {
        return;
    }
//    
//    int dataSize = (int)[data length];
//    char * dataBytes = (char *)[data bytes];
//    int bit = av_get_bytes_per_sample(AV_SAMPLE_FMT_S16) * 8;
//    int channels = (int)[self numOutputChannels];
//    [self.player openAudioFromQueue:dataBytes andWithDataSize:dataSize andWithSampleRate:(int)sample andWithAbit:bit andWithAchannel:channels];
//    //这里设置openal内部缓存数据的大小  太大了视频延迟大  太小了视频会卡顿 根据实际情况调整
//    NSLog(@"++++++++++++++%d",self.player.m_numqueued);
//    if (self.player.m_numqueued > 10 && self.player.m_numqueued < 35) {
//        [NSThread sleepForTimeInterval:0.01];
//    }else if (self.player.m_numqueued > 35){
//        [NSThread sleepForTimeInterval:0.025];
//    }
}

-(void)setData:(NSData *)data
{
    if (data == nil) {
        return;
    }
    
    int dataSize = (int)[data length];
    unsigned char * dataBytes = (unsigned char *)[data bytes];
    int aBit = av_get_bytes_per_sample(AV_SAMPLE_FMT_S16) * 8;
    int aChannel = (int)(self.avcodecContextNumOutputChannels);
//    [self.player openAudioFromQueue:dataBytes withLength:dataSize];
    [self.player openAudioFromQueue:dataBytes andWithDataSize:dataSize andWithSampleRate:self.avcodecContextSamplingRate andWithAbit:aBit andWithAchannel:aChannel];
    //这里设置openal内部缓存数据的大小  太大了视频延迟大  太小了视频会卡顿 根据实际情况调整
    NSLog(@"++++++++++++++%d",self.player.m_numqueued);
    if (self.player.m_numqueued >= 10 && self.player.m_numqueued <= 35) {
        [NSThread sleepForTimeInterval:0.01];
    }else if (self.player.m_numqueued > 35){
        [NSThread sleepForTimeInterval:0.025];
    }
}


- (CYOpenALPlayer *)player
{
    if (!_player)
    {
        _player = [[CYOpenALPlayer alloc] init];
        int aBit = av_get_bytes_per_sample(AV_SAMPLE_FMT_S16) * 8;
        int aChannel = (int)(self.avcodecContextNumOutputChannels);
        //样本数openal的表示方法
        ALenum format = 0;
        if (aBit == 8)
        {
            if (aChannel == 1)
            {
                format = AL_FORMAT_MONO8;
            }
            else if(aChannel == 2)
            {
                format = AL_FORMAT_STEREO8;
            }
        }
        
        if( aBit == 16 )
        {
            if( aChannel == 1 )
            {
                format = AL_FORMAT_MONO16;
            }
            if( aChannel == 2 )
            {
                format = AL_FORMAT_STEREO16;
            }
        }
//        [_player initOpenAL:format :self.samplingRate];
        [_player initOpenAL];
    }
    return _player;
}

- (void)play
{
    [self.player playSound];
}

- (void)stop
{
    [self.player stopSound];
//    self.player = nil;
}

- (void)setPlayRate:(double)playRate
{
    _playRate = playRate;
    self.player.playRate = playRate;
}

- (void)stopAndCleanBuffer
{
    [self.player stopSound];
    [self.player cleanUpOpenAL];
    self.player = nil;
}

- (void)clearBuffer
{
    [self.player clearBuffer];
}

- (void)resetPlayer
{
    [self.player stopSound];
    self.player = nil;
    [self player];
}

- (BOOL)isPlaying
{
    return self.player.isPlaying;
}

- (double)avaudioSessionSamplingRate
{
    double result = [AVAudioSession sharedInstance].sampleRate;
    return result;
}

- (NSInteger)avaudioSessionNumOutputChannels
{
    double result = [AVAudioSession sharedInstance].outputNumberOfChannels;
    return result;
}


# pragma mark - Other
- (void)dealloc
{

}

@end
