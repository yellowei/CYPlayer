//
//  CYOpenALPlayer.m
//  CYPlayer
//
//  Created by 黄威 on 2018/8/31.
//  Copyright © 2018年 Sutan. All rights reserved.
//

#ifdef USE_OLD
#import "CYOpenALPlayer.h"

@implementation CYOpenALPlayer

@synthesize audioFormat;
@synthesize mDevice;
@synthesize mContext;
@synthesize soundDictionary;
@synthesize bufferStorageArray;
@synthesize outSourceID;

#pragma mark - openal function
-(void)initOpenAL:(int)format :(int)sampleRate_
{
    //processed =0;
    //queued =0;
    
    audioFormat = format;
    sampleRate = sampleRate_;
    
    //init the device and context
    mDevice=alcOpenDevice(NULL);
    if (mDevice) {
        mContext=alcCreateContext(mDevice,NULL);
        alcMakeContextCurrent(mContext);
    }
    
    //    ALfloat listenerPos[]={0.0, 0.0,2.0};
    // ALfloat listenerVel[]={0.0,0.0,0.0};
    // ALfloat listenerOri[]={0.0,0.0,-1.0, 0.0,0.0,1.0};// Listener facing into the screen
    
    //soundDictionary = [[NSMutableDictionary alloc]init];// not used
    //bufferStorageArray = [[NSMutableArray alloc]init];// not used
    
    alGenSources(1, &outSourceID);
    
    //
    //    alListenerfv(AL_POSITION,listenerPos); // Position ...
    // alListenerfv(AL_VELOCITY,listenerVel);// Velocity ...
    // alListenerfv(AL_ORIENTATION,listenerOri);// Orientation ...
    
    alSpeedOfSound(1.0);
    alDopplerVelocity(1.0);
    alDopplerFactor(1.0);
    alSourcef(outSourceID,AL_PITCH, 1.0f);
    alSourcef(outSourceID,AL_GAIN, 1.0f);
    alSourcei(outSourceID,AL_LOOPING, AL_FALSE);
    alSourcef(outSourceID,AL_SOURCE_TYPE, AL_STREAMING);
    //alSourcef(outSourceID, AL_BUFFERS_QUEUED, 29);
    
    /*
     updateBufferTimer = [NSTimer scheduledTimerWithTimeInterval: 1/58.0
     target:self
     selector:@selector(updateQueueBuffer)
     userInfo: nil
     repeats:YES];
     */
}


- (BOOL) updateQueueBuffer
{
    ALint stateVaue;
    int processed, queued;
    
    
    alGetSourcei(outSourceID,AL_SOURCE_STATE, &stateVaue);
    
    if (stateVaue ==AL_STOPPED /*||
                                stateVaue == AL_PAUSED ||
                                stateVaue == AL_INITIAL*/)
    {
        //[self playSound];
        return NO;
    }
    
    alGetSourcei(outSourceID,AL_BUFFERS_PROCESSED, &processed);
    alGetSourcei(outSourceID,AL_BUFFERS_QUEUED, &queued);
    
    while(processed > 0 && processed--)
    {
        alSourceUnqueueBuffers(outSourceID,1, &buff);
        alDeleteBuffers(1, &buff);
    }
    
    return YES;
}

- (void)openAudioFromQueue:(unsigned char *)dataBuffer withLength:(int)length
{
    //NSLog(@"Update Audio data and play--------------->/n");
    
    NSCondition* ticketCondition= [[NSCondition alloc] init];
    [ticketCondition lock];
    
    [self updateQueueBuffer];
    
    int ret = 0;
    ALuint bufferID =0;
    alGenBuffers(1, &bufferID);
    if((ret = alGetError()) != AL_NO_ERROR)
    {
        printf("error alGenBuffers %x \n", ret);
        //        printf("error alGenBuffers %x : %s\n", ret, alutGetErrorString(ret));
        //        AL_ILLEGAL_ENUM
        //        AL_INVALID_VALUE
        //        #define AL_ILLEGAL_COMMAND                        0xA004
        //        #define AL_INVALID_OPERATION                      0xA004
    }
    
    alBufferData(bufferID, audioFormat, dataBuffer, length, sampleRate);
    alSourceQueueBuffers(outSourceID,1, &bufferID);
    
    ALint stateVaue;
    alGetSourcei(outSourceID,AL_SOURCE_STATE, &stateVaue);
    
    if (stateVaue == AL_STOPPED || stateVaue == AL_INITIAL)
    {
        alSourcePlay(outSourceID);
        if((ret = alGetError()) != AL_NO_ERROR)
        {
            printf("error alcMakeContextCurrent %x\n", ret);
        }
    }
    
    [ticketCondition unlock];
    ticketCondition = nil;
 
}

#pragma mark - play/stop/clean function
- (BOOL)isPlaying
{
    ALint stateVaue;
    alGetSourcei(outSourceID,AL_SOURCE_STATE, &stateVaue);
    
    return (stateVaue == AL_PLAYING);
}

-(void)playSound
{
    //alSourcePlay(outSourceID);
}

-(void)stopSound
{
    NSLog(@"alSourceStop");
    alSourceStop(outSourceID);
}

-(void)cleanUpOpenAL
{
    int processed = 0;
    int queued = 0;
    NSLog(@"alGetSourcei");
    alGetSourcei(outSourceID,AL_BUFFERS_PROCESSED, &processed);
    alGetSourcei(outSourceID,AL_BUFFERS_QUEUED, &queued);
    while(processed > 0 && processed--) {
        alSourceUnqueueBuffers(outSourceID,1, &buff);
        alDeleteBuffers(1, &buff);
    }
    while(queued > 0 && queued--) {
        alSourceUnqueueBuffers(outSourceID,1, &buff);
        alDeleteBuffers(1, &buff);
    }
    
    NSLog(@"alDeleteSources");
    alDeleteSources(1, &outSourceID);
    
    if (mContext)
    {
        alcMakeContextCurrent(NULL);
        NSLog(@"alcDestroyContext");
        alcDestroyContext(mContext);
        mContext = NULL;
    }
    NSLog(@"alcCloseDevice");
    alcCloseDevice(mDevice);
    mDevice = NULL;
    NSLog(@"alcCloseDevice ---");
    /*
    alcMakeContextCurrent(NULL);
    
    NSLog(@"alcDestroyContext");
    alcDestroyContext(mContext);
    
    NSLog(@"alcCloseDevice");
    alcCloseDevice(mDevice);
    NSLog(@"alcCloseDevice ---");
    */
}

#pragma mark - 供参考  play/stop/clean

// the main method: grab the sound ID from the library
// and start the source playing
- (void)playSound:(NSString*)soundKey
{
    NSNumber* numVal = [soundDictionary objectForKey:soundKey];
    if (numVal ==nil)
        return;
    
    NSUInteger sourceID = [numVal unsignedIntValue];
    alSourcePlay(sourceID);
}

- (void)stopSound:(NSString*)soundKey
{
    NSNumber* numVal = [soundDictionary objectForKey:soundKey];
    if (numVal ==nil)
        return;
    
    NSUInteger sourceID = [numVal unsignedIntValue];
    alSourceStop(sourceID);
}


-(void)cleanUpOpenAL:(id)sender
{
    // delete the sources
    for (NSNumber * sourceNumber in [soundDictionary allValues])
    {
        NSUInteger sourceID = [sourceNumber unsignedIntegerValue];
        alDeleteSources(1, &sourceID);
    }
    
    [soundDictionary removeAllObjects];
    // delete the buffers
    for (NSNumber* bufferNumber in bufferStorageArray)
    {
        NSUInteger bufferID = [bufferNumber unsignedIntegerValue];
        alDeleteBuffers(1, &bufferID);
    }
    [bufferStorageArray removeAllObjects];
    
    // destroy the context
    alcDestroyContext(mContext);
    // close the device
    alcCloseDevice(mDevice);
}


#pragma mark - unused function
////////////////////////////////////////////
//crespo study openal function,need import audiotoolbox framework and 2 header file
////////////////////////////////////////////


// open the audio file
// returns a big audio ID struct
-(AudioFileID)openAudioFile:(NSString*)filePath
{
    AudioFileID outAFID;
    // use the NSURl instead of a cfurlref cuz it is easier
    NSURL * afUrl = [NSURL fileURLWithPath:filePath];
    // do some platform specific stuff..
#if TARGET_OS_IPHONE
    OSStatus result =AudioFileOpenURL((__bridge CFURLRef)afUrl,kAudioFileReadPermission, 0, &outAFID);
#else
    OSStatus result = AudioFileOpenURL((__bridge CFURLRef)afUrl, fsRdPerm,0, &outAFID);
#endif
    if (result !=0)
        NSLog(@"cannot openf file: %@",filePath);
    
    return outAFID;
}


// find the audio portion of the file
// return the size in bytes
-(UInt32)audioFileSize:(AudioFileID)fileDescriptor
{
    UInt64 outDataSize =0;
    UInt32 thePropSize =sizeof(UInt64);
    OSStatus result =AudioFileGetProperty(fileDescriptor,kAudioFilePropertyAudioDataByteCount, &thePropSize, &outDataSize);
    if(result !=0)
        NSLog(@"cannot find file size");
    
    return (UInt32)outDataSize;
}


-(void)dealloc
{
    // NSLog(@"openal sound dealloc");
//    [soundDictionary release];
//    [bufferStorageArray release];
//    [super dealloc];
}

@end

#else

#import "CYOpenALPlayer.h"

@implementation CYOpenALPlayer{
    
    ALCdevice  * m_Devicde;          //device句柄
    ALCcontext * m_Context;         //device context
    ALuint       m_outSourceId;           //source id 负责播放
    NSLock     * lock;
    float        rate;
    dispatch_semaphore_t _bufferLock;
}


- (instancetype)init
{
    if (self = [super init])
    {
        _bufferLock = dispatch_semaphore_create(1);
    }
    return self;
}

- (BOOL)isPlaying
{
    ALint stateVaue;
    alGetSourcei(m_outSourceId,AL_SOURCE_STATE, &stateVaue);
    
    return (stateVaue == AL_PLAYING);
}


-(int)initOpenAL{
    
    int ret = 0;
    lock = [[NSLock alloc]init];
    printf("=======initOpenAl===\n");
    rate = 1.0;
    m_Devicde = alcOpenDevice(NULL);
    if (m_Devicde)
    {
        //建立声音文本描述
        m_Context = alcCreateContext(m_Devicde, NULL);
        //设置行为文本描述
        alcMakeContextCurrent(m_Context);
    }else
        ret = -1;
    
    //创建一个source并设置一些属性
    alGenSources(1, &m_outSourceId);
    alSpeedOfSound(1.0);
    alDopplerVelocity(1.0);
    alDopplerFactor(1.0);
    alSourcef(m_outSourceId, AL_PITCH, 1.0f);
    alSourcef(m_outSourceId, AL_GAIN, 1.0f); //设置音量大小，1.0f表示最大音量。openAL动态调节音量大小就用这个方法
    alSourcei(m_outSourceId, AL_LOOPING, AL_FALSE);// 设置音频播放是否为循环播放，AL_FALSE是不循环
    alSourcef(m_outSourceId, AL_SOURCE_TYPE, AL_STREAMING);// 设置声音数据为流试，（openAL 针对PCM格式数据流）
    alDopplerVelocity(1.0); //多普勒效应，这属于高级范畴，不是游戏开发，对音质没有苛刻要求的话，一般无需设置
    alDopplerFactor(1.0);   //同上
    return ret;
}

-(int)updataQueueBuffer{
    
    
    //播放状态字段
    ALint stateVaue = 0;
    
    //获取处理队列，得出已经播放过的缓冲器的数量
    alGetSourcei(m_outSourceId, AL_BUFFERS_PROCESSED, &_m_numprocessed);
    //获取缓存队列，缓存的队列数量
    alGetSourcei(m_outSourceId, AL_BUFFERS_QUEUED, &_m_numqueued);
    
    //获取播放状态，是不是正在播放
    alGetSourcei(m_outSourceId, AL_SOURCE_STATE, &stateVaue);
    
    //printf("===statevaue ========================%x\n",stateVaue);
    
    if (stateVaue == AL_STOPPED ||
        stateVaue == AL_PAUSED ||
        stateVaue == AL_INITIAL)
    {
        //如果没有数据,或数据播放完了
        if (_m_numqueued < _m_numprocessed || _m_numqueued == 0 ||(_m_numqueued == 1 && _m_numprocessed ==1))
        {
            //停止播放
            printf("...Audio Stop\n");
            [self stopSound];;
            [self cleanUpOpenAL];
            return 0;
        }
        
        if (stateVaue != AL_PLAYING && self.m_numqueued > 10)
        {
            [self playSound];
        }
    }
    //将已经播放过的的数据删除掉
    while(_m_numprocessed --)
    {
        ALuint buff;
        //更新缓存buffer中的数据到source中
        alSourceUnqueueBuffers(m_outSourceId, 1, &buff);
        //删除缓存buff中的数据
        alDeleteBuffers(1, &buff);
        
        //得到已经播放的音频队列多少块
        _m_IsplayBufferSize ++;
    }
    
    return 1;
}

- (void)clearBuffer
{
    //播放状态字段
    ALint stateVaue = 0;
    //获取处理队列，得出已经播放过的缓冲器的数量
    alGetSourcei(m_outSourceId, AL_BUFFERS_PROCESSED, &_m_numprocessed);
    //获取缓存队列，缓存的队列数量
    alGetSourcei(m_outSourceId, AL_BUFFERS_QUEUED, &_m_numqueued);
    
    //获取播放状态，是不是正在播放
    alGetSourcei(m_outSourceId, AL_SOURCE_STATE, &stateVaue);
    
    if (stateVaue == AL_PLAYING) {
        alSourceStop(m_outSourceId);
    }
    
    //将已经播放过的的数据删除掉
    while(_m_numqueued > 0 && _m_numqueued --)
    {
        ALuint buff;
        //更新缓存buffer中的数据到source中
        alSourceUnqueueBuffers(m_outSourceId, 1, &buff);
        //删除缓存buff中的数据
        alDeleteBuffers(1, &buff);
    }
    
    //将已经播放过的的数据删除掉
    while(_m_numprocessed > 0 && _m_numprocessed --)
    {
        ALuint buff;
        //更新缓存buffer中的数据到source中
        alSourceUnqueueBuffers(m_outSourceId, 1, &buff);
        //删除缓存buff中的数据
        alDeleteBuffers(1, &buff);
    }
}

-(void)cleanUpOpenAL{
    
    printf("=======cleanUpOpenAL===\n");
    alDeleteSources(1, &m_outSourceId);
    
    ALCcontext * Context = alcGetCurrentContext();
    // ALCdevice * Devicde = alcGetContextsDevice(Context);
    
    if (Context)
    {
        alcMakeContextCurrent(NULL);
        alcDestroyContext(Context);
        m_Context = NULL;
    }
    alcCloseDevice(m_Devicde);
    m_Devicde = NULL;
}

-(void)playSound{
    
    int ret = 0;
    
    alSourcePlay(m_outSourceId);
    if((ret = alGetError()) != AL_NO_ERROR)
    {
        printf("error alcMakeContextCurrent %x\n", ret);
    }
}

-(void)stopSound{
    
    alSourceStop(m_outSourceId);
}
-(int)openAudioFromQueue:(char*)data andWithDataSize:(int)dataSize andWithSampleRate:(int) aSampleRate andWithAbit:(int)aBit andWithAchannel:(int)aChannel{
    
    int ret = 0;
    //样本数openal的表示方法
    ALenum format = 0;
    //buffer id 负责缓存,要用局部变量每次数据都是新的地址
    ALuint bufferID = 0;
    
    if (_m_datasize == 0 &&
        _m_samplerate == 0 &&
        _m_bit == 0 &&
        _m_channel == 0)
    {
        if (dataSize != 0 &&
            aSampleRate != 0 &&
            aBit != 0 &&
            aChannel != 0)
        {
            _m_datasize = dataSize;
            _m_samplerate = aSampleRate;
            _m_bit = aBit;
            _m_channel = aChannel;
            _m_oneframeduration = _m_datasize * 1.0 /(_m_bit/8) /_m_channel /_m_samplerate * 1000 ;   //计算一帧数据持续时间
        }
    }
    
    //创建一个buffer
    alGenBuffers(1, &bufferID);
    if((ret = alGetError()) != AL_NO_ERROR)
    {
        //播放状态字段
        ALint stateVaue = 0;
        //获取播放状态，是不是正在播放
        alGetSourcei(m_outSourceId, AL_SOURCE_STATE, &stateVaue);
        printf("error alGenBuffers %x \n", ret);
        return ret;
        // printf("error alGenBuffers %x : %s\n", ret,alutGetErrorString (ret));
        //AL_ILLEGAL_ENUM
        //AL_INVALID_VALUE
        //#define AL_ILLEGAL_COMMAND                        0xA004
        //#define AL_INVALID_OPERATION                      0xA004
    }
    
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
    //指定要将数据复制到缓冲区中的数据
    alBufferData(bufferID, format, data, dataSize,aSampleRate);
    if((ret = alGetError()) != AL_NO_ERROR)
    {
        printf("error alBufferData %x\n", ret);
        return ret;
        //AL_ILLEGAL_ENUM
        //AL_INVALID_VALUE
        //#define AL_ILLEGAL_COMMAND                        0xA004
        //#define AL_INVALID_OPERATION                      0xA004
    }
    //附加一个或一组buffer到一个source上
    alSourceQueueBuffers(m_outSourceId, 1, &bufferID);
    if((ret = alGetError()) != AL_NO_ERROR)
    {
        //播放状态字段
        ALint stateVaue = 0;
        //获取播放状态，是不是正在播放
        alGetSourcei(m_outSourceId, AL_SOURCE_STATE, &stateVaue);
        printf("error alSourceQueueBuffers %x\n", ret);
        return ret;
    }
    
    //更新队列数据
    ret = [self updataQueueBuffer];
    
    bufferID = 0;
    
    return ret;
}

- (void)setM_volume:(float)m_volume{
    
    self.m_volume = m_volume;
    alSourcef(m_outSourceId,AL_GAIN,m_volume);
}

- (float)m_volume{
    return self.m_volume;
}

-(void)setPlayRate:(double)playRate{
    
    alSourcef(m_outSourceId, AL_PITCH, playRate);
}

@end

#endif
