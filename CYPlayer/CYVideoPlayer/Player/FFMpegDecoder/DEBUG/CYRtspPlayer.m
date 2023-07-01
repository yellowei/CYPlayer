//
//  CYRtspPlayer.m
//  CYPlayer
//
//  Created by 黄威 on 2018/7/17.
//  Copyright © 2018年 Sutan. All rights reserved.
//

#import "CYRtspPlayer.h"
#import "Utilities.h"
#import "AudioStreamer.h"

@interface CYRtspPlayer ()
@property (nonatomic, copy) NSString *cruutenPath;
@property (nonatomic, assign) BOOL useTcp;
@property (nonatomic, retain) AudioStreamer * audioController;
@end

@implementation CYRtspPlayer
{
    AVFormatContext     *CYFormatCtx;
    AVCodecContext      *CYVideoCodecCtx;
    AVCodecContext      *CYAudioCodecCtx;
    AVFrame             *video_frame;
    AVFrame             *audio_frame;
    AVStream            *video_Stream;
    AVStream            *audio_Stream;
    AVPacket            packet;
    AVPicture           picture;
    int                 videoStream;
    int                 audioStream;
    double              fps;
    BOOL                isReleaseResources;
    
    //音频相关
    NSUInteger          _audioBufferSize;
    int16_t             *_audioBuffer;
    BOOL                _inBuffer;
    int                 audioPacketQueueSize;
    NSMutableArray      *audioPacketQueue;
    NSLock              *audioPacketQueueLock;
    BOOL                primed;
    AVPacket            *_packet, _currentPacket;
}

@synthesize audioController = _audioController;
@synthesize audioPacketQueue,audioPacketQueueSize;
@synthesize CYAudioCodecCtx;
@synthesize emptyAudioBuffer;

#pragma mark ------------------------------------
#pragma mark  初始化
- (instancetype)initWithVideo:(NSString *)moviePath {
    
    if (!(self=[super init])) return nil;
    if ([self initializeResources:[moviePath UTF8String] usesTcp:NO]) {
        self.cruutenPath = [moviePath copy];
        return self;
    } else {
        return nil;
    }
}

- (id)initWithVideo:(NSString *)moviePath usesTcp:(BOOL)usesTcp
{
    if (!(self=[super init])) return nil;
    if ([self initializeResources:[moviePath UTF8String] usesTcp:usesTcp]) {
        self.cruutenPath = [moviePath copy];
        return self;
    } else {
        return nil;
    }
}

- (BOOL)initializeResources:(const char *)filePath usesTcp:(BOOL)usesTcp
{
    
    isReleaseResources = NO;
    AVCodec *pCodec;//视频
    AVCodec *aCodec;//音频
    // 注册所有解码器
    avcodec_register_all();
    av_register_all();
    avformat_network_init();
    
    // Set the RTSP Options,使用TCP or UDP
    AVDictionary *opts = 0;
    if (usesTcp)
    {
        av_dict_set(&opts, "rtsp_transport", "tcp", 0);
        self.useTcp = YES;
    }
    else
    {
        self.useTcp = NO;
    }
    // 打开视频文件

    if (avformat_open_input(&CYFormatCtx, filePath, NULL, &opts) != 0) {
        NSLog(@"打开文件失败");
        goto initError;
    }
    // 检查数据流
    if (avformat_find_stream_info(CYFormatCtx, NULL) < 0) {
        NSLog(@"检查数据流失败");
        goto initError;
    }
    // 根据数据流,找到第一个视频流
    if ((videoStream =  av_find_best_stream(CYFormatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &pCodec, 0)) < 0) {
        NSLog(@"没有找到第一个视频流");
        videoStream = -1;
    }
    
    // 根据数据流,找到第一个音频流
    if ((audioStream =  av_find_best_stream(CYFormatCtx, AVMEDIA_TYPE_AUDIO, -1, -1, &aCodec, 0)) < 0) {
        NSLog(@"没有找到第一个音频流");
        audioStream = -1;
    }
    
    if (videoStream==-1 && audioStream==-1) {
        goto initError;
    }
    
    // 获取视频流的编解码上下文的指针
    video_Stream      = CYFormatCtx->streams[videoStream];
    CYVideoCodecCtx = avcodec_alloc_context3(NULL);
    avcodec_parameters_to_context(CYVideoCodecCtx, video_Stream->codecpar);
#if DEBUG
    // 打印视频流的详细信息
    av_dump_format(CYFormatCtx, videoStream, filePath, 0);
#endif
    if(video_Stream->avg_frame_rate.den && video_Stream->avg_frame_rate.num)
    {
        fps = av_q2d(video_Stream->avg_frame_rate);
    }
    else
    {
        fps = 30;
    }
    // 查找解码器
        pCodec = avcodec_find_decoder(CYVideoCodecCtx->codec_id);
    if (pCodec == NULL) {
        NSLog(@"没有找到video解码器");
        goto initError;
    }
    // 打开解码器
    if(avcodec_open2(CYVideoCodecCtx, pCodec, NULL) < 0) {
        NSLog(@"打开video解码器失败");
        goto initError;
    }
    
    if (audioStream > -1)
    {
        NSLog(@"set up audiodecoder");
        [self setupAudioDecoderWithCodec:aCodec];
    }
    
    // 分配视频帧
    video_frame = av_frame_alloc();
    _outputWidth = CYVideoCodecCtx->width;
    _outputHeight = CYVideoCodecCtx->height;
    return YES;
initError:
    return NO;
}
- (void)seekTime:(double)seconds {
    AVRational timeBase = CYFormatCtx->streams[videoStream]->time_base;
    int64_t targetFrame = (int64_t)((double)timeBase.den / timeBase.num * seconds);
    avformat_seek_file(CYFormatCtx,
                       videoStream,
                       0,
                       targetFrame,
                       targetFrame,
                       AVSEEK_FLAG_FRAME);
    avcodec_flush_buffers(CYVideoCodecCtx);
}
- (BOOL)stepFrame {

    int frameFinished = 0;
    while (!frameFinished && av_read_frame(CYFormatCtx, &packet) >= 0)
    {
        
        if (packet.stream_index == videoStream)
        {
            if (CYVideoCodecCtx)
            {
                avcodec_send_packet(CYVideoCodecCtx, &packet);
                if (avcodec_receive_frame(CYVideoCodecCtx, video_frame) == 0)
                {
                    frameFinished = 1;
                }
            }
            
            av_packet_unref(&packet);//解决内存av_read_frame泄露问题
        }
        else if (packet.stream_index == audioStream)
        {
            if (CYAudioCodecCtx)
            {
                avcodec_send_packet(CYAudioCodecCtx, &packet);
                if (avcodec_receive_frame(CYAudioCodecCtx, audio_frame) == 0)
                {
                    frameFinished = 1;
                }
                
                [audioPacketQueueLock lock];
                
                audioPacketQueueSize += packet.size;
                [audioPacketQueue addObject:[NSMutableData dataWithBytes:&packet length:sizeof(packet)]];
                
                [audioPacketQueueLock unlock];
                
                if (!primed) {
                    primed=YES;
                    [_audioController _startAudio];
                }
                
                if (emptyAudioBuffer) {
                    [_audioController enqueueBuffer:emptyAudioBuffer];
                }
            }
        }
        
    }
    if (frameFinished == 0 && isReleaseResources == NO)
    {
        [self releaseResources];
    }
    return frameFinished != 0;
}

- (void)replaceTheResources:(NSString *)moviePath {
    if (!isReleaseResources) {
        [self releaseResources];
    }
    self.cruutenPath = [moviePath copy];
    [self initializeResources:[moviePath UTF8String] usesTcp:NO];
}

- (void)replaceTheResources:(NSString *)moviePath usesTcp:(BOOL)usesTcp {
    if (!isReleaseResources) {
        [self releaseResources];
    }
    self.cruutenPath = [moviePath copy];
    [self initializeResources:[moviePath UTF8String] usesTcp:usesTcp];
}

- (void)redialPaly {
    [self initializeResources:[self.cruutenPath UTF8String] usesTcp:self.useTcp];
}

#pragma mark ------------------------------------
#pragma mark  重写属性访问方法
-(void)setOutputWidth:(int)newValue {
    if (_outputWidth == newValue) return;
    _outputWidth = newValue;
}
-(void)setOutputHeight:(int)newValue {
    if (_outputHeight == newValue) return;
    _outputHeight = newValue;
}
-(UIImage *)currentImage {
    if (!video_frame->data[0]) return nil;
    return [self imageFromAVPicture];
}
-(double)duration {
    return (double)CYFormatCtx->duration / AV_TIME_BASE;
}
- (double)currentTime {
    AVRational timeBase = CYFormatCtx->streams[videoStream]->time_base;
    return packet.pts * (double)timeBase.num / timeBase.den;
}
- (int)sourceWidth {
    return CYVideoCodecCtx->width;
}
- (int)sourceHeight {
    return CYVideoCodecCtx->height;
}
- (double)fps {
    return fps;
}
- (void)savePPMPicture:(AVPicture)pict width:(int)width height:(int)height index:(int)iFrame
{
    FILE *pFile;
    NSString *fileName;
    int  y;
    
    fileName = [Utilities documentsPath:[NSString stringWithFormat:@"image%04d.ppm",iFrame]];
    // Open file
    NSLog(@"write image file: %@",fileName);
    pFile=fopen([fileName cStringUsingEncoding:NSASCIIStringEncoding], "wb");
    if (pFile == NULL) {
        return;
    }
    
    // Write header
    fprintf(pFile, "P6\n%d %d\n255\n", width, height);
    
    // Write pixel data
    for (y=0; y<height; y++) {
        fwrite(pict.data[0]+y*pict.linesize[0], 1, width*3, pFile);
    }
    
    // Close file
    fclose(pFile);
}

- (AVCodecContext *)getAudioCodecCtx
{
    return CYAudioCodecCtx;
}


#pragma mark --------------------------
#pragma mark - 公开方法
- (void)closeAudio
{
    [_audioController _stopAudio];
    primed=NO;
}

- (AVPacket*)readAudioPacket
{
    if (_currentPacket.size > 0 || _inBuffer) return &_currentPacket;
    
    NSMutableData *packetData = [audioPacketQueue objectAtIndex:0];
    _packet = [packetData mutableBytes];
    
    if (_packet) {
        if (_packet->dts != AV_NOPTS_VALUE) {
            _packet->dts += av_rescale_q(0, AV_TIME_BASE_Q, audio_Stream->time_base);
        }
        
        if (_packet->pts != AV_NOPTS_VALUE) {
            _packet->pts += av_rescale_q(0, AV_TIME_BASE_Q, audio_Stream->time_base);
        }
        
        [audioPacketQueueLock lock];
        audioPacketQueueSize -= _packet->size;
        if ([audioPacketQueue count] > 0) {
            [audioPacketQueue removeObjectAtIndex:0];
        }
        [audioPacketQueueLock unlock];
        
        _currentPacket = *(_packet);
    }
    
    return &_currentPacket;
}


#pragma mark --------------------------
#pragma mark - 内部方法
- (void)setupAudioDecoderWithCodec:(AVCodec *)aCodec
{
    if (audioStream >= 0) {
        _audioBufferSize = 192000;
        _audioBuffer = av_malloc(_audioBufferSize);
        _inBuffer = NO;
        audio_frame = av_frame_alloc();
        
        // 获取音频流的编解码上下文的指针
        audio_Stream      = CYFormatCtx->streams[audioStream];
        CYAudioCodecCtx = avcodec_alloc_context3(NULL);
        avcodec_parameters_to_context(CYAudioCodecCtx, audio_Stream->codecpar);
        
        if (aCodec == NULL) {
            NSLog(@"没有找到audio解码器");
        }
        
        // 打开解码器
        if(avcodec_open2(CYAudioCodecCtx, aCodec, NULL) < 0) {
            NSLog(@"打开video解码器失败");
        }
        
        if (audioPacketQueue) {
            audioPacketQueue = nil;
        }
        audioPacketQueue = [[NSMutableArray alloc] init];
        
        if (audioPacketQueueLock) {
            audioPacketQueueLock = nil;
        }
        audioPacketQueueLock = [[NSLock alloc] init];
        
        if (_audioController) {
            [_audioController _stopAudio];
            _audioController = nil;
        }
        _audioController = [[AudioStreamer alloc] initWithStreamer:self];
    }
    else
    {
        CYFormatCtx->streams[audioStream]->discard = AVDISCARD_ALL;
        audioStream = -1;
    }
}

- (UIImage *)imageFromAVPicture
{
    avpicture_free(&picture);
    avpicture_alloc(&picture, AV_PIX_FMT_RGB24, _outputWidth, _outputHeight);
    struct SwsContext * imgConvertCtx = sws_getContext(CYVideoCodecCtx->width,
                                                       CYVideoCodecCtx->height,
                                                       CYVideoCodecCtx->pix_fmt,
                                                       _outputWidth,
                                                       _outputHeight,
                                                       AV_PIX_FMT_RGB24,
                                                       SWS_FAST_BILINEAR,
                                                       NULL,
                                                       NULL,
                                                       NULL);
    if(imgConvertCtx == nil) return nil;
    sws_scale(imgConvertCtx,
              video_frame->data,
              video_frame->linesize,
              0,
              video_frame->height,
              picture.data,
              picture.linesize);
    sws_freeContext(imgConvertCtx);
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreate(kCFAllocatorDefault,
                                  picture.data[0],
                                  picture.linesize[0] * _outputHeight);
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(_outputWidth,
                                       _outputHeight,
                                       8,
                                       24,
                                       picture.linesize[0],
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    CFRelease(data);
    
    return image;
}

#pragma mark --------------------------
#pragma mark - 释放资源
- (void)releaseResources {
    NSLog(@"释放资源");
    //    SJLogFunc
    isReleaseResources = YES;
    // 释放RGB
    avpicture_free(&picture);
    // 释放frame
    av_packet_unref(&packet);
    
    // 释放YUV frame
    av_free(video_frame);
    av_free(audio_frame);
    // 关闭解码器
    if (CYVideoCodecCtx) avcodec_close(CYVideoCodecCtx);
    if (CYAudioCodecCtx) avcodec_close(CYAudioCodecCtx);
    // 关闭文件
    if (CYFormatCtx) avformat_close_input(&CYFormatCtx);
    avformat_network_deinit();
}

-(void)dealloc
{
    [self releaseResources];
}

@end
