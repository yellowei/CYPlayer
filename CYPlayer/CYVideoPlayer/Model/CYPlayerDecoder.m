//
//  CYPlayerDecoder.m
//  cyplayer
//
//  Created by yellowei on 15.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/yellowei/cyplayer
//  this file is part of CYPlayer
//  CYPlayer is licenced under the LGPL v3, see lgpl-3.0.txt

#import "CYPlayerDecoder.h"
#import <Accelerate/Accelerate.h>
#import <CYFFmpeg/CYFFmpeg.h>
#import "CYPCMAudioManager.h"
#import "CYAudioManager.h"
#import "CYLogger.h"
#import "CYOpenALPlayer.h"
#import <objc/runtime.h>
#import "CYVideoPlayerResources.h"
#import "CYHardwareDecompressVideo.h"
#import "CYSonicManager.h"
#import <malloc/malloc.h>
#import "CYGCDManager.h"

#define CY_DocumentDir [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]
#define CY_CachesDir [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]
#define CY_BundlePath(res) [[NSBundle mainBundle] pathForResource:res ofType:nil]
#define CY_DocumentPath(res) [CY_DocumentDir stringByAppendingPathComponent:res]
#define CY_CachesPath(res) [CY_CachesDir stringByAppendingPathComponent:res]

//#define USE_OPENAL @"UseCYPCMAudioManager"

#define USE_AUDIOTOOL @"UseCYAudioManager"

////////////////////////////////////////////////////////////////////////////////
NSString * cyplayerErrorDomain = @"com.yellowei.www.CYPlayer";
NSInteger CYPlayerDecoderMaxFPS = 60;
NSInteger CYPlayerDecoderConCurrentThreadCount = 1;// range: 1 - 5;

# pragma mark - struct CYPicture

typedef struct CYPicture {
    uint8_t *data[AV_NUM_DATA_POINTERS];    ///< pointers to the image data planes
    int linesize[AV_NUM_DATA_POINTERS];     ///< number of bytes per line
} CYPicture;

int cypicture_alloc(CYPicture *picture,
                    enum AVPixelFormat pix_fmt, int width, int height)
{
    int ret = av_image_alloc(picture->data, picture->linesize,
                             width, height, pix_fmt, 1);
    if (ret < 0) {
        memset(picture, 0, sizeof(CYPicture));
        return ret;
    }
    
    return 0;
}

void cypicture_free(CYPicture *picture)
{
    av_freep(&picture->data[0]);
}

# pragma mark - static methods

static void FFLog(void* context, int level, const char* format, va_list args);

static NSError * cyplayerError (NSInteger code, id info)
{
    NSDictionary *userInfo = nil;
    
    if ([info isKindOfClass: [NSDictionary class]]) {
        
        userInfo = info;
        
    } else if ([info isKindOfClass: [NSString class]]) {
        
        userInfo = @{ NSLocalizedDescriptionKey : info };
    }
    
    return [NSError errorWithDomain:cyplayerErrorDomain
                               code:code
                           userInfo:userInfo];
}

static NSString * errorMessage (cyPlayerError errorCode)
{
    switch (errorCode) {
        case cyPlayerErrorNone:
            return @"";
            
        case cyPlayerErrorOpenFile:
            return NSLocalizedString(@"Unable to open file", nil);
            
        case cyPlayerErrorStreamInfoNotFound:
            return NSLocalizedString(@"Unable to find stream information", nil);
            
        case cyPlayerErrorStreamNotFound:
            return NSLocalizedString(@"Unable to find stream", nil);
            
        case cyPlayerErrorCodecNotFound:
            return NSLocalizedString(@"Unable to find codec", nil);
            
        case cyPlayerErrorOpenCodec:
            return NSLocalizedString(@"Unable to open codec", nil);
            
        case cyPlayerErrorAllocateFrame:
            return NSLocalizedString(@"Unable to allocate frame", nil);
            
        case cyPlayerErroSetupScaler:
            return NSLocalizedString(@"Unable to setup scaler", nil);
            
        case cyPlayerErroReSampler:
            return NSLocalizedString(@"Unable to setup resampler", nil);
            
        case cyPlayerErroUnsupported:
            return NSLocalizedString(@"The ability is not supported", nil);
            
        case cyPlayerErroOpenFilter:
            return NSLocalizedString(@"The avfilter can`t open", nil);
    }
}

////////////////////////////////////////////////////////////////////////////////

static BOOL audioCodecIsSupported(AVCodecContext *audio)
{
    if (audio->sample_fmt == AV_SAMPLE_FMT_S16) {
#ifdef USE_OPENAL
        CYPCMAudioManager * audioManager = [CYPCMAudioManager audioManager];
        return  (int)audioManager.avaudioSessionSamplingRate == audio->sample_rate &&
                audioManager.avaudioSessionNumOutputChannels == audio->channels;
#endif
#ifdef USE_AUDIOTOOL
        id<CYAudioManager> audioManager = [CYAudioManager audioManager];
        return  (int)audioManager.samplingRate == audio->sample_rate &&
        audioManager.numOutputChannels == audio->channels;
#endif
    }
    return NO;
}

#ifdef DEBUG
static void fillSignal(SInt16 *outData,  UInt32 numFrames, UInt32 numChannels)
{
    static float phase = 0.0;
    
    for (int i=0; i < numFrames; ++i)
    {
        for (int iChannel = 0; iChannel < numChannels; ++iChannel)
        {
            float theta = phase * M_PI * 2;
            outData[i*numChannels + iChannel] = sin(theta) * (float)INT16_MAX;
        }
        phase += 1.0 / (44100 / 440.0);
        if (phase > 1.0) phase = -1;
    }
}

static void fillSignalF(float *outData,  UInt32 numFrames, UInt32 numChannels)
{
    static float phase = 0.0;
    
    for (int i=0; i < numFrames; ++i)
    {
        for (int iChannel = 0; iChannel < numChannels; ++iChannel)
        {
            float theta = phase * M_PI * 2;
            outData[i*numChannels + iChannel] = sin(theta);
        }
        phase += 1.0 / (44100 / 440.0);
        if (phase > 1.0) phase = -1;
    }
}

static void testConvertYUV420pToRGB(AVFrame * frame, uint8_t *outbuf, int linesize, int height)
{
    const int linesizeY = frame->linesize[0];
    const int linesizeU = frame->linesize[1];
    const int linesizeV = frame->linesize[2];
    
    assert(height == frame->height);
    assert(linesize  <= linesizeY * 3);
    assert(linesizeY == linesizeU * 2);
    assert(linesizeY == linesizeV * 2);
    
    uint8_t *pY = frame->data[0];
    uint8_t *pU = frame->data[1];
    uint8_t *pV = frame->data[2];
    
    const int width = linesize / 3;
    
    for (int y = 0; y < height; y += 2) {
        
        uint8_t *dst1 = outbuf + y       * linesize;
        uint8_t *dst2 = outbuf + (y + 1) * linesize;
        
        uint8_t *py1  = pY  +  y       * linesizeY;
        uint8_t *py2  = py1 +            linesizeY;
        uint8_t *pu   = pU  + (y >> 1) * linesizeU;
        uint8_t *pv   = pV  + (y >> 1) * linesizeV;
        
        for (int i = 0; i < width; i += 2) {
            
            int Y1 = py1[i];
            int Y2 = py2[i];
            int Y3 = py1[i+1];
            int Y4 = py2[i+1];
            
            int U = pu[(i >> 1)] - 128;
            int V = pv[(i >> 1)] - 128;
            
            int dr = (int)(             1.402f * V);
            int dg = (int)(0.344f * U + 0.714f * V);
            int db = (int)(1.772f * U);
            
            int r1 = Y1 + dr;
            int g1 = Y1 - dg;
            int b1 = Y1 + db;
            
            int r2 = Y2 + dr;
            int g2 = Y2 - dg;
            int b2 = Y2 + db;
            
            int r3 = Y3 + dr;
            int g3 = Y3 - dg;
            int b3 = Y3 + db;
            
            int r4 = Y4 + dr;
            int g4 = Y4 - dg;
            int b4 = Y4 + db;
            
            r1 = r1 > 255 ? 255 : r1 < 0 ? 0 : r1;
            g1 = g1 > 255 ? 255 : g1 < 0 ? 0 : g1;
            b1 = b1 > 255 ? 255 : b1 < 0 ? 0 : b1;
            
            r2 = r2 > 255 ? 255 : r2 < 0 ? 0 : r2;
            g2 = g2 > 255 ? 255 : g2 < 0 ? 0 : g2;
            b2 = b2 > 255 ? 255 : b2 < 0 ? 0 : b2;
            
            r3 = r3 > 255 ? 255 : r3 < 0 ? 0 : r3;
            g3 = g3 > 255 ? 255 : g3 < 0 ? 0 : g3;
            b3 = b3 > 255 ? 255 : b3 < 0 ? 0 : b3;
            
            r4 = r4 > 255 ? 255 : r4 < 0 ? 0 : r4;
            g4 = g4 > 255 ? 255 : g4 < 0 ? 0 : g4;
            b4 = b4 > 255 ? 255 : b4 < 0 ? 0 : b4;
            
            dst1[3*i + 0] = r1;
            dst1[3*i + 1] = g1;
            dst1[3*i + 2] = b1;
            
            dst2[3*i + 0] = r2;
            dst2[3*i + 1] = g2;
            dst2[3*i + 2] = b2;
            
            dst1[3*i + 3] = r3;
            dst1[3*i + 4] = g3;
            dst1[3*i + 5] = b3;
            
            dst2[3*i + 3] = r4;
            dst2[3*i + 4] = g4;
            dst2[3*i + 5] = b4;            
        }
    }
}
#endif

static void avStreamFPSTimeBase(AVStream *st, CGFloat defaultTimeBase, CGFloat *pFPS, CGFloat *pTimeBase)
{
    CGFloat fps, timebase;
    
    AVCodecContext *codecCtx_tmp = avcodec_alloc_context3(NULL);
    avcodec_parameters_to_context(codecCtx_tmp, st->codecpar);
//    AVCodecContext *codecCtx_tmp = st->codec;
    
    if (st->time_base.den && st->time_base.num)
        timebase = av_q2d(st->time_base);
    else if(codecCtx_tmp->time_base.den && codecCtx_tmp->time_base.num)
        timebase = av_q2d(codecCtx_tmp->time_base);
    else
        timebase = defaultTimeBase;
        
    if (codecCtx_tmp->ticks_per_frame != 1) {
        LoggerStream(0, @"WARNING: st.codec.ticks_per_frame=%d", codecCtx_tmp->ticks_per_frame);
        //timebase *= codecCtx_tmp->ticks_per_frame;
    }
         
    if (st->avg_frame_rate.den && st->avg_frame_rate.num)
        fps = av_q2d(st->avg_frame_rate);
    else if (st->r_frame_rate.den && st->r_frame_rate.num)
        fps = av_q2d(st->r_frame_rate);
    else
        fps = 1.0 / timebase;
    
    if (pFPS)
        *pFPS = fps;
    if (pTimeBase)
        *pTimeBase = timebase;
    
    avcodec_free_context(&codecCtx_tmp);

}

static NSArray *collectStreams(AVFormatContext *formatCtx, enum AVMediaType codecType)
{
    NSMutableArray *ma = [NSMutableArray array];
    for (NSInteger i = 0; i < formatCtx->nb_streams; ++i)
    {
        AVStream * video_Stream      = formatCtx->streams[i];
        AVCodecContext *codecCtx = avcodec_alloc_context3(NULL);
        avcodec_parameters_to_context(codecCtx, video_Stream->codecpar);
        if (codecType == codecCtx->codec_type)
        {
            [ma addObject: [NSNumber numberWithInteger: i]];
        }
        avcodec_free_context(&codecCtx);
    }
    return [ma copy];
}

static NSData * copyFrameData(UInt8 *src, int linesize, int width, int height)
{
    @autoreleasepool {
        if (linesize == width)
        {
            NSMutableData * data = [NSMutableData dataWithBytes:src length:width * height];
            return data;
        }
        else
        {
            width = MIN(linesize, width);
            NSMutableData *md = [NSMutableData dataWithLength: width * height];
            Byte *dst = md.mutableBytes;
            for (NSUInteger i = 0; i < height; ++i) {
                memcpy(dst, src, width);
                dst += width;
                src += linesize;
            }
            return md;
        }
    }
    
}

static BOOL isNetworkPath (NSString *path)
{
    NSRange r = [path rangeOfString:@":"];
    if (r.location == NSNotFound)
        return NO;
    NSString *scheme = [path substringToIndex:r.length];
    if ([scheme isEqualToString:@"file"])
        return NO;
    return YES;
}

static int interrupt_callback(void *ctx);

#ifdef SMBCLIENT_H_INCLUDED
static int my_libsmbc_open( URLContext *h, const char *url, int flags);
static int my_libsmbc_close( URLContext *h );
static int my_libsmbc_close2( URLContext *h );
static int my_libsmbc_connect(URLContext *h);
#endif

# pragma mark - ///////////////////////////

@interface CYPlayerFrame()
@property (readwrite, nonatomic) CGFloat position;
@property (readwrite, nonatomic) CGFloat duration;
@end

@implementation CYPlayerFrame

@end

@interface CYAudioFrame()
@property (readwrite, nonatomic, strong) NSData *samples;
@end

@implementation CYAudioFrame
- (CYPlayerFrameType) type { return CYPlayerFrameTypeAudio; }

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init]) {
    
        self.position = [aDecoder decodeDoubleForKey:@"position"];
        
        self.duration = [aDecoder decodeDoubleForKey:@"duration"];
        
        self.samples = [aDecoder decodeObjectForKey:@"samples"];
    }
    return self;
}


-(void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeDouble:self.position forKey:@"position"];
    
    [aCoder encodeDouble:self.duration forKey:@"duration"];
    
    [aCoder encodeObject:self.samples forKey:@"samples"];
}
@end

@interface CYVideoFrame()
@property (readwrite, nonatomic) NSUInteger width;
@property (readwrite, nonatomic) NSUInteger height;
@end

@implementation CYVideoFrame
- (CYPlayerFrameType) type { return CYPlayerFrameTypeVideo; }

- (void)dealloc
{
#ifdef DEBUG
//    NSLog(@"%@ dealloc", NSStringFromClass([self class]));
#endif
}
@end

@interface CYVideoFrameRGB ()
@property (readwrite, nonatomic) NSUInteger linesize;
@property (readwrite, nonatomic, strong) NSData *rgb;
@end

@implementation CYVideoFrameRGB
- (CYVideoFrameFormat) format { return CYVideoFrameFormatRGB; }
- (UIImage *) asImage
{
    UIImage *image = nil;
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)(_rgb));
    if (provider) {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        if (colorSpace) {
            CGImageRef imageRef = CGImageCreate(self.width,
                                                self.height,
                                                8,
                                                24,
                                                self.linesize,
                                                colorSpace,
                                                kCGBitmapByteOrderDefault,
                                                provider,
                                                NULL,
                                                YES, // NO
                                                kCGRenderingIntentDefault);
            
            if (imageRef) {
                image = [UIImage imageWithCGImage:imageRef];
                CGImageRelease(imageRef);
            }
            CGColorSpaceRelease(colorSpace);
        }
        CGDataProviderRelease(provider);
    }
    
    return image;
}

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init]) {
        
        self.position = [aDecoder decodeDoubleForKey:@"position"];
        
        self.duration = [aDecoder decodeDoubleForKey:@"duration"];
        
        self.width = [aDecoder decodeIntegerForKey:@"width"];
        
        self.height = [aDecoder decodeIntegerForKey:@"height"];
        
        self.linesize = [aDecoder decodeIntegerForKey:@"linesize"];
        
        self.rgb = [aDecoder decodeObjectForKey:@"rgb"];
        
    }
    return self;
}


-(void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeDouble:self.position forKey:@"position"];
    
    [aCoder encodeDouble:self.duration forKey:@"duration"];
    
    [aCoder encodeInteger:self.width forKey:@"width"];
    
    [aCoder encodeInteger:self.height forKey:@"height"];
    
    [aCoder encodeInteger:self.linesize forKey:@"linesize"];
    
    [aCoder encodeObject:self.rgb forKey:@"rgb"];
}
@end

@interface CYVideoFrameYUV()
@property (readwrite, nonatomic, strong) NSData *luma;
@property (readwrite, nonatomic, strong) NSData *chromaB;
@property (readwrite, nonatomic, strong) NSData *chromaR;
@property (readwrite, nonatomic, assign) NSInteger * lineSize;
@property (readwrite, nonatomic, assign) CVPixelBufferRef pixelBuffer;
@end

@implementation CYVideoFrameYUV
- (CYVideoFrameFormat) format { return CYVideoFrameFormatYUV; }

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init]) {
        
        self.position = [aDecoder decodeDoubleForKey:@"position"];
        
        self.duration = [aDecoder decodeDoubleForKey:@"duration"];
        
        self.width = [aDecoder decodeIntegerForKey:@"width"];
        
        self.height = [aDecoder decodeIntegerForKey:@"height"];
        
        self.luma = [aDecoder decodeObjectForKey:@"luma"];
        
        self.chromaB = [aDecoder decodeObjectForKey:@"chromaB"];
        
        self.chromaR = [aDecoder decodeObjectForKey:@"chromaR"];
    }
    return self;
}


-(void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeDouble:self.position forKey:@"position"];
    
    [aCoder encodeDouble:self.duration forKey:@"duration"];
    
    [aCoder encodeDouble:self.width forKey:@"width"];
    
    [aCoder encodeDouble:self.height forKey:@"height"];
    
    [aCoder encodeObject:self.luma forKey:@"luma"];
    
    [aCoder encodeObject:self.chromaB forKey:@"chromaB"];
    
    [aCoder encodeObject:self.chromaR forKey:@"chromaR"];
}


@end

@interface CYArtworkFrame()
@property (readwrite, nonatomic, strong) NSData *picture;
@end

@implementation CYArtworkFrame
- (CYPlayerFrameType) type { return CYPlayerFrameTypeArtwork; }
- (UIImage *) asImage
{
    UIImage *image = nil;
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)(_picture));
    if (provider) {
        
        CGImageRef imageRef = CGImageCreateWithJPEGDataProvider(provider,
                                                                NULL,
                                                                YES,
                                                                kCGRenderingIntentDefault);
        if (imageRef) {
            
            image = [UIImage imageWithCGImage:imageRef];
            CGImageRelease(imageRef);
        }
        CGDataProviderRelease(provider);
    }
    
    return image;

}

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init]) {
        
        self.position = [aDecoder decodeDoubleForKey:@"position"];
        
        self.duration = [aDecoder decodeDoubleForKey:@"duration"];
        
        self.picture = [aDecoder decodeObjectForKey:@"picture"];
    }
    return self;
}


-(void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeDouble:self.position forKey:@"position"];
    
    [aCoder encodeDouble:self.duration forKey:@"duration"];
    
    [aCoder encodeObject:self.picture forKey:@"picture"];
}
@end

@interface CYSubtitleFrame()
@property (readwrite, nonatomic, strong) NSString *text;
@end

@implementation CYSubtitleFrame
- (CYPlayerFrameType) type { return CYPlayerFrameTypeSubtitle; }

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init]) {
        
        self.position = [aDecoder decodeDoubleForKey:@"position"];
        
        self.duration = [aDecoder decodeDoubleForKey:@"duration"];
        
        self.text = [aDecoder decodeObjectForKey:@"text"];
    }
    return self;
}


-(void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeDouble:self.position forKey:@"position"];
    
    [aCoder encodeDouble:self.duration forKey:@"duration"];
    
    [aCoder encodeObject:self.text forKey:@"text"];
}
@end

//MARK: - //////////////Decoder///////////////


typedef struct AVIOInternal {
    URLContext *h;
} AVIOInternal;

#ifdef SMBCLIENT_H_INCLUDED
typedef struct {
    const AVClass *class;
    SMBCCTX *ctx;
    int dh;
    int fd;
    int64_t filesize;
    int trunc;
    int timeout;
    char *workgroup;
} LIBSMBContext;

extern  URLProtocol ff_libsmbclient_protocol;
#endif

@interface CYPlayerDecoder () {
    
    AVDictionary        *_options;
    AVFormatContext     *_formatCtx;
	AVCodecContext      *_videoCodecCtx;
    AVCodecContext      *_audioCodecCtx;
    AVCodecContext      *_subtitleCodecCtx;
    
    //Handle Video Frames
    AVFrame             *_videoFrame;
    AVFrame             *_videoFrame1;
    AVFrame             *_videoFrame2;
    AVFrame             *_videoFrame3;
    AVFrame             *_videoFrame4;
    CYPicture           _picture;
    CYPicture           _picture1;
    CYPicture           _picture2;
    CYPicture           _picture3;
    CYPicture           _picture4;
    BOOL                _pictureValid;
    BOOL                _pictureValid1;
    BOOL                _pictureValid2;
    BOOL                _pictureValid3;
    BOOL                _pictureValid4;
    //Handle Audio Frames
    AVFrame             *_audioFrame;
    AVFrame             *_audioFrame1;
    AVFrame             *_audioFrame2;
    AVFrame             *_audioFrame3;
    AVFrame             *_audioFrame4;
    
    
    //滤镜相关
    AVFilterContext     *_buffersrc_ctx;
    AVFilterContext     *_buffersink_ctx;
    
    NSInteger           _videoStream;
    NSInteger           _audioStream;
    NSInteger           _subtitleStream;
	
    
    struct SwsContext   *_swsContext;
    CGFloat             _videoTimeBase;
    CGFloat             _audioTimeBase;
    CGFloat             _position;
    NSArray             *_videoStreams;
    NSArray             *_audioStreams;
    NSArray             *_subtitleStreams;
    SwrContext          *_swrContext;
    
    unsigned char       *_swrBuffer;
    NSUInteger          _swrBufferSize;
    NSDictionary        *_info;
    CYVideoFrameFormat  _videoFrameFormat;
    NSUInteger          _artworkStream;
    NSInteger           _subtitleASSEvents;
    FILE                *_out_fb;
    NSInteger           _fileCount;
    int                 _dstWidth;
    int                 _dstHeight;
    CYPlayerDecoderDynamicFPS _dynamicFPS_Block;//动态帧率控制
    
    
    CVPixelBufferPoolRef _pixelBufferPool;//转CVPixelBuffer时用到的复用池
}

@property (readwrite, nonatomic) BOOL validFilter;
@property (readwrite, nonatomic, strong) CYHardwareDecompressVideo *hwDecompressor;

@end

@implementation CYPlayerDecoder

@dynamic duration;
@dynamic position;
@dynamic frameWidth;
@dynamic frameHeight;
@dynamic sampleRate;
@dynamic audioStreamsCount;
@dynamic subtitleStreamsCount;
@dynamic selectedAudioStream;
@dynamic selectedSubtitleStream;
@dynamic validAudio;
@dynamic validVideo;
@dynamic validSubtitles;
@dynamic info;
@dynamic videoStreamFormatName;
@dynamic startTime;
@dynamic dynamicFPS_Block;


- (NSDictionary *) info
{
    if (!_info) {
        
        NSMutableDictionary *md = [NSMutableDictionary dictionary];
        
        if (_formatCtx) {
        
            const char *formatName = _formatCtx->iformat->name;
            [md setValue: [NSString stringWithCString:formatName encoding:NSUTF8StringEncoding]
                  forKey: @"format"];
            
            if (_formatCtx->bit_rate) {
                
                [md setValue: [NSNumber numberWithInt:(int)(_formatCtx->bit_rate)]
                      forKey: @"bitrate"];
            }
            
            if (_formatCtx->metadata) {
                
                NSMutableDictionary *md1 = [NSMutableDictionary dictionary];
                
                AVDictionaryEntry *tag = NULL;
                 while((tag = av_dict_get(_formatCtx->metadata, "", tag, AV_DICT_IGNORE_SUFFIX))) {
                     
                     [md1 setValue: [NSString stringWithCString:tag->value encoding:NSUTF8StringEncoding]
                            forKey: [NSString stringWithCString:tag->key encoding:NSUTF8StringEncoding]];
                 }
                
                [md setValue: [md1 copy] forKey: @"metadata"];
            }
        
            char buf[256];
            
            if (_videoStreams.count) {
                NSMutableArray *ma = [NSMutableArray array];
                for (NSNumber *n in _videoStreams) {
                    AVStream *st = _formatCtx->streams[n.integerValue];
                    AVCodecContext *codecCtx_tmp = avcodec_alloc_context3(NULL);
                    avcodec_parameters_to_context(codecCtx_tmp, st->codecpar);
                    avcodec_string(buf, sizeof(buf), codecCtx_tmp, 1);
                    NSString *s = [NSString stringWithCString:buf encoding:NSUTF8StringEncoding];
                    if ([s hasPrefix:@"Video: "])
                        s = [s substringFromIndex:@"Video: ".length];
                    s = [s stringByAppendingString:[NSString stringWithFormat:@", %.0f FPS", _fps]];
                    [ma addObject:s];
                    avcodec_free_context(&codecCtx_tmp);
                }
                md[@"video"] = ma.copy;
            }
            
            if (_audioStreams.count) {
                NSMutableArray *ma = [NSMutableArray array];
                for (NSNumber *n in _audioStreams) {
                    AVStream *st = _formatCtx->streams[n.integerValue];
                    
                    NSMutableString *ms = [NSMutableString string];
                    AVDictionaryEntry *lang = av_dict_get(st->metadata, "language", NULL, 0);
                    if (lang && lang->value) {
                        [ms appendFormat:@"%s ", lang->value];
                    }
                    
                    AVCodecContext *codecCtx_tmp = avcodec_alloc_context3(NULL);
                    avcodec_parameters_to_context(codecCtx_tmp, st->codecpar);
                    avcodec_string(buf, sizeof(buf), codecCtx_tmp, 1);
                    NSString *s = [NSString stringWithCString:buf encoding:NSUTF8StringEncoding];
                    if ([s hasPrefix:@"Audio: "])
                        s = [s substringFromIndex:@"Audio: ".length];
                    [ms appendString:s];
                    
                    [ma addObject:ms.copy];
                    avcodec_free_context(&codecCtx_tmp);
                }                
                md[@"audio"] = ma.copy;
            }
            
            if (_subtitleStreams.count) {
                NSMutableArray *ma = [NSMutableArray array];
                for (NSNumber *n in _subtitleStreams) {
                    AVStream *st = _formatCtx->streams[n.integerValue];
                    
                    NSMutableString *ms = [NSMutableString string];
                    AVDictionaryEntry *lang = av_dict_get(st->metadata, "language", NULL, 0);
                    if (lang && lang->value) {
                        [ms appendFormat:@"%s ", lang->value];
                    }
                    
                    AVCodecContext *codecCtx_tmp = avcodec_alloc_context3(NULL);
                    avcodec_parameters_to_context(codecCtx_tmp, st->codecpar);
                    avcodec_string(buf, sizeof(buf), codecCtx_tmp, 1);
                    NSString *s = [NSString stringWithCString:buf encoding:NSUTF8StringEncoding];
                    if ([s hasPrefix:@"Subtitle: "])
                        s = [s substringFromIndex:@"Subtitle: ".length];
                    [ms appendString:s];
                    
                    [ma addObject:ms.copy];
                    avcodec_free_context(&codecCtx_tmp);
                }               
                md[@"subtitles"] = ma.copy;
            }
            
        }
                
        _info = [md copy];
    }
    
    return _info;
}

- (NSString *) videoStreamFormatName
{
    if (!_videoCodecCtx)
        return nil;
    
    if (_videoCodecCtx->pix_fmt == AV_PIX_FMT_NONE)
        return @"";
    
    const char *name = av_get_sample_fmt_name(_videoCodecCtx->sample_fmt);
    return name ? [NSString stringWithCString:name encoding:NSUTF8StringEncoding] : @"?";
}

- (CGFloat) startTime
{
    if ([self validVideo]) {
        
        AVStream *st = _formatCtx->streams[_videoStream];
        if (AV_NOPTS_VALUE != st->start_time)
            return st->start_time * _videoTimeBase;
        return 0;
    }
    
    if ([self validAudio]) {
        
        AVStream *st = _formatCtx->streams[_audioStream];
        if (AV_NOPTS_VALUE != st->start_time)
            return st->start_time * _audioTimeBase;
        return 0;
    }
        
    return 0;
}

+ (void)initialize
{
//    av_log_set_callback(FFLog);
    //替换ffmpeg的samba protocol的方法
#ifdef SMBCLIENT_H_INCLUDED
    ff_libsmbclient_protocol.url_open = my_libsmbc_open;
    ff_libsmbclient_protocol.url_close = my_libsmbc_close;
#endif
    
    avcodec_register_all();
    av_register_all();
    avformat_network_init();
    avfilter_register_all();
}

- (instancetype)init
{
    if (self = [super init])
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChangeListenerCallback:)   name:AVAudioSessionRouteChangeNotification object:nil];
        _rate = 1.0;
    }
    return self;
}

+ (id) movieDecoderWithContentPath: (NSString *) path
                             error: (NSError **) perror
{
    CYPlayerDecoder *mp = [[CYPlayerDecoder alloc] init];
    if (mp) {
        [mp openFile:path error:perror];
    }
    return mp;
}

- (void) dealloc
{
    LoggerStream(2, @"%@ dealloc", self);
    [self closeFile];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Getter/Setter
- (void)setTargetPosition:(CGFloat)targetPosition
{
    _targetPosition = targetPosition;
}

- (CGFloat) duration
{
    if (!_formatCtx)
        return 0;
    if (_formatCtx->duration == AV_NOPTS_VALUE)
        return MAXFLOAT;
    return (CGFloat)_formatCtx->duration / AV_TIME_BASE;
}

- (CGFloat) position
{
    return _position;
}

- (void) setPosition: (CGFloat)seconds
{
    _position = seconds;
    _isEOF = NO;
    dispatch_semaphore_wait([CYGCDManager sharedManager].av_send_receive_packet_lock, DISPATCH_TIME_FOREVER);//加锁
    dispatch_semaphore_wait([CYGCDManager sharedManager].av_read_frame_lock, DISPATCH_TIME_FOREVER);//加锁
    if ([self validVideo]) {
//        int64_t ts = (int64_t)(seconds / (_videoTimeBase ));
//        avformat_seek_file(_formatCtx, (int)_videoStream, ts, ts, ts, AVSEEK_FLAG_FRAME);
        
        /*
         timebase指的是时间戳，对应pts时间戳，如果index是-1，则使用AV_TIMEBASE作为timebase并由ffmpeg自动转换成默认时间戳， 如果指定了stream那么就要使用相应的stream的timebase来计算pts了。这里注意的是比如seek到32s不能简单的直接32*AV_TIMEBASE来计算时间戳，因为pts不一定是从0开始的，所以要加上起始的pts
         */
//        av_seek_frame(_formatCtx, (int)_videoStream, ts, AVSEEK_FLAG_BACKWARD);
        av_seek_frame(_formatCtx, -1, (seconds)*AV_TIME_BASE + (double)_formatCtx->start_time, AVSEEK_FLAG_BACKWARD);//不指定stream进行seek
        avcodec_flush_buffers(_videoCodecCtx);
        if ([self validAudio]) {
//            int64_t ts = (int64_t)(seconds / (_audioTimeBase));
//            av_seek_frame(_formatCtx, (int)_audioStream, ts, AVSEEK_FLAG_ANY);
            avcodec_flush_buffers(_audioCodecCtx);
        }
        
//        if ([self validAudio]) {
//            int64_t ts = (int64_t)(seconds / (_audioTimeBase));
//            //        avformat_seek_file(_formatCtx, (int)_audioStream, ts, ts, ts, AVSEEK_FLAG_FRAME);
//            av_seek_frame(_formatCtx, (int)_audioStream, ts, AVSEEK_FLAG_ANY);
//            avcodec_flush_buffers(_audioCodecCtx);
//        }
    }else if ([self validAudio]) {
//        int64_t ts = (int64_t)(seconds / (_audioTimeBase));
        //        avformat_seek_file(_formatCtx, (int)_audioStream, ts, ts, ts, AVSEEK_FLAG_FRAME);
//        av_seek_frame(_formatCtx, (int)_audioStream, ts, AVSEEK_FLAG_BACKWARD);
        av_seek_frame(_formatCtx, -1, (seconds)*AV_TIME_BASE + (double)_formatCtx->start_time, AVSEEK_FLAG_BACKWARD);//不指定stream进行seek
        avcodec_flush_buffers(_audioCodecCtx);
    }
    
    
    
    dispatch_semaphore_signal([CYGCDManager sharedManager].av_read_frame_lock);//放行
    dispatch_semaphore_signal([CYGCDManager sharedManager].av_send_receive_packet_lock);
}

- (NSUInteger) frameWidth
{
    if (_dstWidth > 0) {
        return _dstWidth;
    }
    int width = _videoCodecCtx->width;
    int height = _videoCodecCtx->height;
    get_video_scale_max_size(_videoCodecCtx, &width, &height);
    return width ? width : 0;
}

- (NSUInteger) frameHeight
{
    if (_dstHeight > 0)
    {
        return _dstHeight;
    }
    int width = _videoCodecCtx->width;
    int height = _videoCodecCtx->height;
    get_video_scale_max_size(_videoCodecCtx, &width, &height);
    return height ? height : 0;
}

- (CGFloat) sampleRate
{
    return _audioCodecCtx ? _audioCodecCtx->sample_rate : 0;
}

- (NSUInteger) audioStreamsCount
{
    return [_audioStreams count];
}

- (NSUInteger) subtitleStreamsCount
{
    return [_subtitleStreams count];
}

- (NSInteger) selectedAudioStream
{
    if (_audioStream == -1)
        return -1;
    NSNumber *n = [NSNumber numberWithInteger:_audioStream];
    return [_audioStreams indexOfObject:n];
}

- (void) setSelectedAudioStream:(NSInteger)selectedAudioStream
{
    NSInteger audioStream = [_audioStreams[selectedAudioStream] integerValue];
    [self closeAudioStream];
    cyPlayerError errCode = [self openAudioStream: audioStream];
    if (cyPlayerErrorNone != errCode) {
        LoggerAudio(0, @"%@", errorMessage(errCode));
    }
}

- (NSInteger) selectedSubtitleStream
{
    if (_subtitleStream == -1)
        return -1;
    return [_subtitleStreams indexOfObject:@(_subtitleStream)];
}

- (void) setSelectedSubtitleStream:(NSInteger)selected
{
    [self closeSubtitleStream];
    
    if (selected == -1) {
        
        _subtitleStream = -1;
        
    } else {
        
        NSInteger subtitleStream = [_subtitleStreams[selected] integerValue];
        cyPlayerError errCode = [self openSubtitleStream:subtitleStream];
        if (cyPlayerErrorNone != errCode) {
            LoggerStream(0, @"%@", errorMessage(errCode));
        }
    }
}

- (BOOL) validAudio
{
    return (_audioStream != -1) && (self.decodeType & CYVideoDecodeTypeAudio);
}

- (BOOL) validVideo
{
    return (_videoStream != -1) && (self.decodeType & CYVideoDecodeTypeVideo);
}

- (BOOL) validSubtitles
{
    return _subtitleStream != -1;
}

- (CYPlayerDecoderDynamicFPS)dynamicFPS_Block
{
    __block CYPlayerDecoderDynamicFPS tempBlock;
    dispatch_sync([CYGCDManager sharedManager].setter_getter_concurrent_queue, ^{
        tempBlock = _dynamicFPS_Block;
    });
    return tempBlock;
}

- (void)setDynamicFPS_Block:(CYPlayerDecoderDynamicFPS)dynamicFPS_Block
{
    __weak typeof(self)weakSelf = self;
    dispatch_barrier_async([CYGCDManager sharedManager].setter_getter_concurrent_queue, ^{
        __strong typeof(&*weakSelf)strongSelf = weakSelf;
        if (strongSelf) {
            strongSelf->_dynamicFPS_Block = dynamicFPS_Block;
        }
    });
}



#pragma mark - private

- (BOOL) openFile: (NSString *) path
            error: (NSError **) perror
{
    NSAssert(path, @"nil path");
    NSAssert(!_formatCtx, @"already open");
    
    _isNetwork = isNetworkPath(path);
    
    static BOOL needNetworkInit = YES;
    if (needNetworkInit && _isNetwork) {
        
        needNetworkInit = NO;
        avformat_network_init();
    }
    
    path = path.length > 0 ? path : @"";
    _path = path;
    dispatch_semaphore_wait([CYGCDManager sharedManager].av_read_frame_lock, DISPATCH_TIME_FOREVER);//加锁
    cyPlayerError errCode = [self openInput: path];
    dispatch_semaphore_signal([CYGCDManager sharedManager].av_read_frame_lock);//放行
    
    if (errCode == cyPlayerErrorNone) {
        
        cyPlayerError videoErr = cyPlayerErrorOpenCodec;
        cyPlayerError audioErr = cyPlayerErrorOpenCodec;
        
        videoErr = [self openVideoStream];
        
        audioErr = [self openAudioStream];
        
        _subtitleStream = -1;
        
        if (videoErr != cyPlayerErrorNone &&
            audioErr != cyPlayerErrorNone) {
         
            errCode = videoErr; // both fails
            
        } else {
            
            _subtitleStreams = collectStreams(_formatCtx, AVMEDIA_TYPE_SUBTITLE);
            if (videoErr == cyPlayerErrorNone)
            {
//                [self openFilter];
//                self.hwDecompressor = [[CYHardwareDecompressVideo alloc] initWithCodecCtx:_videoCodecCtx];
            }
        }
    }
    
    if (errCode != cyPlayerErrorNone) {
        
        [self closeFile];
        NSString *errMsg = errorMessage(errCode);
        LoggerStream(0, @"%@, %@", errMsg, path.lastPathComponent);
        if (perror)
            *perror = cyplayerError(errCode, errMsg);
        return NO;
    }
        
    return YES;
}

- (cyPlayerError) openInput: (NSString *) path
{
    AVFormatContext *formatCtx = NULL;

    if (_interruptCallback) {
        
        formatCtx = avformat_alloc_context();
        if (!formatCtx)
            return cyPlayerErrorOpenFile;
        
        __weak typeof(&*self)weakSelf = self;
        AVIOInterruptCB cb = {
            interrupt_callback,
            (__bridge void *)(weakSelf)
        };
        formatCtx->interrupt_callback = cb;
    }
    else
    {
        formatCtx = avformat_alloc_context();
        if (!formatCtx)
            return cyPlayerErrorOpenFile;
    }
    

    
    av_dict_set(&_options, "rtsp_transport", "udp", 0);//设置tcp or udp，默认一般优先tcp再尝试udp
//    av_dict_set(&_options, "stimeout", "3000000", 0);//设置超时3秒
//    av_dict_set(&_options, "timeout", "30000000", 0);//设置超时30秒
//    av_dict_set(&_options, "timeout", NULL, 0);
//    av_dict_set(&_options, "re", "25", 0);
//    av_dict_set(&_options, "r", "25", 0);
//    av_dict_set(&_options, "qp", "0", 0);
//    av_dict_set(&_options, "video_size","3264x2448",0);
//    av_dict_set(&_options,"pixel_format","yuv420p",0);
//    av_dict_set(&_options, "f", "h264", 0);
//    av_dict_set(&_options, "codec:v", "h264", 0);
//    av_dict_set(&_options, "codec:a", "aac", 0);
//    av_dict_set(&_options, "probesize", "32M", 0);
//    av_dict_set_int(&_options, "video_track_timescale", 25, 0);
//    av_dict_set_int(&_options, "fpsprobesize", 25, 0);
//    av_dict_set_int(&_options, "skip-calc-frame-rate", 25, 0);
    av_dict_set(&_options, "buffer_size", "1024000", 0);
    
//#ifdef aaa
    int ret;
    if (( ret = formatCtx->io_open(formatCtx, &formatCtx->pb, [path UTF8String], AVIO_FLAG_READ | formatCtx->avio_flags, &_options)) < 0){
        return cyPlayerErrorOpenFile;
    }
    
    AVIOContext * pb = formatCtx->pb;
    AVIOInternal * internal = pb->opaque;
    URLContext * h = internal->h;
    const URLProtocol * prot = h->prot;
    
    if ([[NSString stringWithUTF8String:prot->name] isEqualToString:@"smb"]) {
//        LIBSMBContext *libsmbc = h->priv_data;
//        h->prot->url_open = my_libsmbc_open;
//        h->prot->url_close = my_libsmbc_close;
    }
    
    if ([self.path hasPrefix:@"rtsp"] || [self.path hasPrefix:@"rtmp"] || [[self.path lastPathComponent] containsString:@"m3u8"]) {
        // There is total different meaning for 'timeout' option in rtmp
        av_dict_set(&_options, "timeout", NULL, 0);
    }
    
//#endif
    
    //avformat_open_input-->init_input
    //init_input-->(io_open:io_open_default)
    //io_open_default-->ffio_open_whitelist-->ffurl_open_whitelist
    //ffurl_open_whitelist--(URLContext)-->ffio_fdopen
    
    if (avformat_open_input(&formatCtx, [path cStringUsingEncoding: NSUTF8StringEncoding], NULL, &_options) < 0) {
        
        if (formatCtx)
            avformat_free_context(formatCtx);
        return cyPlayerErrorOpenFile;
    }

    
    
    if (avformat_find_stream_info(formatCtx, NULL) < 0) {
        
        avformat_close_input(&formatCtx);
        return cyPlayerErrorStreamInfoNotFound;
    }

#if DEBUG
    // 打印视频流的详细信息
   av_dump_format(formatCtx, 0, [path.lastPathComponent cStringUsingEncoding: NSUTF8StringEncoding], false);
#endif
    
    
    _formatCtx = formatCtx;
    
    return cyPlayerErrorNone;
}

- (cyPlayerError) openFilter
{
    cyPlayerError errCode = cyPlayerErroOpenFilter;
    _validFilter = NO;
    if (filters_init(_formatCtx, &_buffersrc_ctx, &_buffersink_ctx, CYPlayerFilter_FILTER_NULL) >= 0)
    {
        errCode = cyPlayerErrorNone;
        _validFilter = YES;
    }
    return errCode;
}

- (cyPlayerError) openVideoStream
{
    cyPlayerError errCode = cyPlayerErrorStreamNotFound;
    _videoStream = -1;
    _artworkStream = -1;
    if (!(self.decodeType & CYVideoDecodeTypeVideo))
    {
        return cyPlayerErrorStreamNotFound;
    }
    _videoStreams = collectStreams(_formatCtx, AVMEDIA_TYPE_VIDEO);
    for (NSNumber *n in _videoStreams) {
        
        const NSUInteger iStream = n.integerValue;

        if (0 == (_formatCtx->streams[iStream]->disposition & AV_DISPOSITION_ATTACHED_PIC)) {
            if (1) {
                errCode = [self openHWVideoStream: iStream];
            } else {
                errCode = [self openVideoStream: iStream];
            }
            
            if (errCode == cyPlayerErrorNone)
                break;
            
        } else {
            
            _artworkStream = iStream;
        }
    }
    
    return errCode;
}

- (AVCodecContext *)createVideoEncderWithFormatContext:(AVFormatContext *)formatContext stream:(AVStream *)stream videoStreamIndex:(int)videoStreamIndex {
    AVCodecContext *codecContext = NULL;
    AVCodec *codec = NULL;
    
    NSString * kModuleName = @"createVideoEncderWithFormatContext";
    // 指定解码器名称, 这里使用苹果VideoToolbox中的硬件解码器
    const char *codecName = av_hwdevice_get_type_name(AV_HWDEVICE_TYPE_VIDEOTOOLBOX);
    // 将解码器名称转为对应的枚举类型
    enum AVHWDeviceType type = av_hwdevice_find_type_by_name(codecName);
    if (type != AV_HWDEVICE_TYPE_VIDEOTOOLBOX) {
        LoggerVideo(kModuleName, @"%s: Not find hardware codec.",__func__);
        return NULL;
    }
    
    // 根据解码器枚举类型找到解码器
    int ret = av_find_best_stream(formatContext, AVMEDIA_TYPE_VIDEO, -1, -1, &codec, 0);
    if (ret < 0) {
        LoggerVideo(kModuleName, @"av_find_best_stream faliture");
        return NULL;
    }
    
    // 为解码器上下文对象分配内存
    codecContext = avcodec_alloc_context3(codec);
    if (!codecContext){
        LoggerVideo(kModuleName, @"avcodec_alloc_context3 faliture");
        return NULL;
    }
    
    // 将视频流中的参数填充到视频解码器中
    ret = avcodec_parameters_to_context(codecContext, formatContext->streams[videoStreamIndex]->codecpar);
    if (ret < 0){
        LoggerVideo(kModuleName, @"avcodec_parameters_to_context faliture");
        return NULL;
    }
    
    // 创建硬件解码器上下文
    ret = InitHardwareDecoder(codecContext, type);
    if (ret < 0){
        LoggerVideo(kModuleName, @"hw_decoder_init faliture");
        return NULL;
    }
    
    // 初始化解码器上下文对象
    ret = avcodec_open2(codecContext, codec, NULL);
    if (ret < 0) {
        LoggerVideo(kModuleName, @"avcodec_open2 faliture");
        return NULL;
    }
    
    return codecContext;
}

#pragma mark - C Function
AVBufferRef *hw_device_ctx = NULL;
static int InitHardwareDecoder(AVCodecContext *ctx, const enum AVHWDeviceType type) {
    int err = av_hwdevice_ctx_create(&hw_device_ctx, type, NULL, NULL, 0);
    if (err < 0) {
        LoggerVideo(@"XDXParseParse", @"Failed to create specified HW device.\n");
        return err;
    }
    ctx->hw_device_ctx = av_buffer_ref(hw_device_ctx);
    return err;
}

- (cyPlayerError) openHWVideoStream: (NSInteger) videoStream
{
    // get a pointer to the codec context for the video stream
    
    AVCodecContext *codecContext = NULL;
    AVCodec *codec = NULL;
//    AVStream * video_Stream      = _formatCtx->streams[videoStream];
    // 指定解码器名称, 这里使用苹果VideoToolbox中的硬件解码器
    const char *codecName = av_hwdevice_get_type_name(AV_HWDEVICE_TYPE_VIDEOTOOLBOX);
    // 将解码器名称转为对应的枚举类型
    enum AVHWDeviceType type = av_hwdevice_find_type_by_name(codecName);
    if (type != AV_HWDEVICE_TYPE_VIDEOTOOLBOX) {
        LoggerVideo(kModuleName, @"%s: Not find hardware codec.",__func__);
        return cyPlayerErrorCodecNotFound;
    }
    
    // 根据解码器枚举类型找到解码器
    int ret = av_find_best_stream(_formatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &codec, 0);
    if (ret < 0) {
        LoggerVideo(kModuleName, @"av_find_best_stream faliture");
        return cyPlayerErrorCodecNotFound;
    }
    
    if (!codec) {
        return cyPlayerErrorCodecNotFound;
    }
    
    // 为解码器上下文对象分配内存
    codecContext = avcodec_alloc_context3(codec);
    if (!codecContext){
        LoggerVideo(kModuleName, @"avcodec_alloc_context3 faliture");
        return cyPlayerErrorCodecNotFound;
    }
    
    // 将视频流中的参数填充到视频解码器中
    ret = avcodec_parameters_to_context(codecContext, _formatCtx->streams[videoStream]->codecpar);
    if (ret < 0){
        LoggerVideo(kModuleName, @"avcodec_parameters_to_context faliture");
        return cyPlayerErrorCodecNotFound;
    }
    
    // 创建硬件解码器上下文
    ret = InitHardwareDecoder(codecContext, type);
    if (ret < 0){
        LoggerVideo(kModuleName, @"hw_decoder_init faliture");
        return cyPlayerErrorCodecNotFound;
    }
    
    // 初始化解码器上下文对象
    ret = avcodec_open2(codecContext, codec, NULL);
    if (ret < 0) {
        LoggerVideo(kModuleName, @"avcodec_open2 faliture");
        return cyPlayerErrorCodecNotFound;
    }
    
    AVCodecContext *codecCtx = codecContext;
//    avcodec_parameters_to_context(codecCtx, video_Stream->codecpar);

    
    // find the decoder for the video stream
//    AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
//    if (!codec)
//        return cyPlayerErrorCodecNotFound;
    
    // inform the codec that we can handle truncated bitstreams -- i.e.,
    // bitstreams where frame boundaries can fall in the middle of packets
//    if(codec->capabilities & CODEC_CAP_TRUNCATED)
//    {
//        codecCtx->flags |= CODEC_FLAG_TRUNCATED;
//    }
    codecCtx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    codecCtx->thread_count = 4;
//    codecCtx->thread_type = FF_THREAD_FRAME;
    // open codec
//    if (avcodec_open2(codecCtx, codec, NULL) < 0)
//        return cyPlayerErrorOpenCodec;
        
    _videoFrame = av_frame_alloc();
    _videoFrame1 = av_frame_alloc();
    _videoFrame2 = av_frame_alloc();
    _videoFrame3 = av_frame_alloc();
    _videoFrame4 = av_frame_alloc();

    if (!_videoFrame || !_videoFrame1 || !_videoFrame2 || !_videoFrame3 || !_videoFrame4) {
        avcodec_free_context(&codecCtx);
        return cyPlayerErrorAllocateFrame;
    }
    
    _videoStream = videoStream;
    _videoCodecCtx = codecCtx;
    
//    unsigned char *dummy=NULL;   //输入的指针
//    int dummy_len;
//    AVBitStreamFilterContext* bsfc =  av_bitstream_filter_init("h264_mp4toannexb");
//    av_bitstream_filter_filter(bsfc, _videoCodecCtx, NULL, &dummy, &dummy_len, NULL, 0, 0);
//    av_bitstream_filter_close(bsfc);
//    free(dummy);
    
    // determine fps
    AVStream *st = _formatCtx->streams[_videoStream];
    avStreamFPSTimeBase(st, 0.04, &_fps, &_videoTimeBase);
    
    LoggerVideo(1, @"video codec size: %d:%d fps: %.3f tb: %f",
                (int)(self.frameWidth),
                (int)(self.frameHeight),
                _fps,
                _videoTimeBase);
    
    LoggerVideo(1, @"video start time %f", st->start_time * _videoTimeBase);
    LoggerVideo(1, @"video disposition %d", st->disposition);
    
    st = NULL;
    
//    AVHWAccel *pp = ff_find_hwaccel(_videoCodecCtx->codec_id, _videoCodecCtx->pix_fmt);
    return cyPlayerErrorNone;
}

- (cyPlayerError) openVideoStream: (NSInteger) videoStream
{    
    // get a pointer to the codec context for the video stream
    
    //    AVCodecContext *codecCtx = _formatCtx->streams[videoStream]->codec;
    AVStream * video_Stream      = _formatCtx->streams[videoStream];
    AVCodecContext *codecCtx = avcodec_alloc_context3(NULL);
    avcodec_parameters_to_context(codecCtx, video_Stream->codecpar);

    
    // find the decoder for the video stream
    AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
    if (!codec)
        return cyPlayerErrorCodecNotFound;
    
    // inform the codec that we can handle truncated bitstreams -- i.e.,
    // bitstreams where frame boundaries can fall in the middle of packets
//    if(codec->capabilities & CODEC_CAP_TRUNCATED)
//    {
//        codecCtx->flags |= CODEC_FLAG_TRUNCATED;
//    }
    codecCtx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    codecCtx->thread_count = 4;
//    codecCtx->thread_type = FF_THREAD_FRAME;
    // open codec
    if (avcodec_open2(codecCtx, codec, NULL) < 0)
        return cyPlayerErrorOpenCodec;
        
    _videoFrame = av_frame_alloc();
    _videoFrame1 = av_frame_alloc();
    _videoFrame2 = av_frame_alloc();
    _videoFrame3 = av_frame_alloc();
    _videoFrame4 = av_frame_alloc();

    if (!_videoFrame || !_videoFrame1 || !_videoFrame2 || !_videoFrame3 || !_videoFrame4) {
        avcodec_free_context(&codecCtx);
        return cyPlayerErrorAllocateFrame;
    }
    
    _videoStream = videoStream;
    _videoCodecCtx = codecCtx;
    
//    unsigned char *dummy=NULL;   //输入的指针
//    int dummy_len;
//    AVBitStreamFilterContext* bsfc =  av_bitstream_filter_init("h264_mp4toannexb");
//    av_bitstream_filter_filter(bsfc, _videoCodecCtx, NULL, &dummy, &dummy_len, NULL, 0, 0);
//    av_bitstream_filter_close(bsfc);
//    free(dummy);
    
    // determine fps
    AVStream *st = _formatCtx->streams[_videoStream];
    avStreamFPSTimeBase(st, 0.04, &_fps, &_videoTimeBase);
    
    LoggerVideo(1, @"video codec size: %d:%d fps: %.3f tb: %f",
                (int)(self.frameWidth),
                (int)(self.frameHeight),
                _fps,
                _videoTimeBase);
    
    LoggerVideo(1, @"video start time %f", st->start_time * _videoTimeBase);
    LoggerVideo(1, @"video disposition %d", st->disposition);
    
    st = NULL;
    
//    AVHWAccel *pp = ff_find_hwaccel(_videoCodecCtx->codec_id, _videoCodecCtx->pix_fmt);
    return cyPlayerErrorNone;
}

- (cyPlayerError) openAudioStream
{
    cyPlayerError errCode = cyPlayerErrorStreamNotFound;
    _audioStream = -1;
    if (!(self.decodeType & CYVideoDecodeTypeAudio))
    {
        return cyPlayerErrorStreamNotFound;
    }
    _audioStreams = collectStreams(_formatCtx, AVMEDIA_TYPE_AUDIO);
    for (NSNumber *n in _audioStreams) {
    
        errCode = [self openAudioStream: n.integerValue];
        if (errCode == cyPlayerErrorNone)
            break;
    }    
    return errCode;
}

- (cyPlayerError) openAudioStream: (NSInteger) audioStream
{
    AVCodecContext *codecCtx = avcodec_alloc_context3(NULL);
    avcodec_parameters_to_context(codecCtx, _formatCtx->streams[audioStream]->codecpar);
    SwrContext *swrContext = NULL;
                   
    AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
    if(!codec)
        return cyPlayerErrorCodecNotFound;
        
    if (avcodec_open2(codecCtx, codec, NULL) < 0)
         return cyPlayerErrorOpenCodec;
    
    if (!audioCodecIsSupported(codecCtx)) {
        
#ifdef USE_OPENAL
        CYPCMAudioManager * audioManager = [CYPCMAudioManager audioManager];
        [[CYPCMAudioManager audioManager] setPlayRate: 1 / _rate];
        [audioManager setAudioCtx:codecCtx];

        audioManager.avcodecContextNumOutputChannels = audioManager.avaudioSessionNumOutputChannels;
        if (codecCtx->sample_rate < CYPCMAudioManagerNormalSampleRate)
        {
            audioManager.avcodecContextSamplingRate = codecCtx->sample_rate;
        }
        else
        {
            audioManager.avcodecContextSamplingRate = CYPCMAudioManagerNormalSampleRate;
        }

        dispatch_semaphore_wait[CYGCDManager sharedManager].swr_context_lock, DISPATCH_TIME_FOREVER);
        BOOL result = audio_swr_resampling_audio_init(&swrContext, codecCtx, _rate) <= 0;
        dispatch_semaphore_signal([CYGCDManager sharedManager].swr_context_lock);
        if (result)
        {
            return cyPlayerErroReSampler;
        }
#endif
#ifdef USE_AUDIOTOOL
        id<CYAudioManager> audioManager = [CYAudioManager audioManager];
        audioManager.avcodecContextNumOutputChannels = audioManager.numOutputChannels;
        {
            audioManager.avcodecContextSamplingRate = audioManager.samplingRate;
        }
        
        dispatch_semaphore_wait([CYGCDManager sharedManager].swr_context_lock, DISPATCH_TIME_FOREVER);
        BOOL result = audio_swr_resampling_audio_init(&swrContext, codecCtx, _rate) <= 0;
        dispatch_semaphore_signal([CYGCDManager sharedManager].swr_context_lock);
        if (result)
        {
            return cyPlayerErroReSampler;
        }
#endif
    }
    _audioFrame = av_frame_alloc();
    _audioFrame1 = av_frame_alloc();
    _audioFrame2 = av_frame_alloc();
    _audioFrame3 = av_frame_alloc();
    _audioFrame4 = av_frame_alloc();

    if (!_audioFrame || !_audioFrame1 || !_audioFrame2 || !_audioFrame3 || !_audioFrame4) {
        if (swrContext)
        {
            swr_free(&swrContext);
        }
        avcodec_free_context(&codecCtx);
        return cyPlayerErrorAllocateFrame;
    }
    
    _audioStream = audioStream;
    _audioCodecCtx = codecCtx;
    _swrContext = swrContext;
    
    AVStream *st = _formatCtx->streams[_audioStream];

//    int64_t out_sample_rate;
//    if (_swrContext)
//    {
//        av_opt_get_int(_swrContext, "out_sample_rate", 0, &out_sample_rate);
//        _audioTimeBase = 1.0 / out_sample_rate;
//    }
//    else
    {
        avStreamFPSTimeBase(st, 0.025, 0, &_audioTimeBase);
    }
    
    
    
    LoggerAudio(1, @"audio codec smr: %.d fmt: %d chn: %d tb: %f %@",
                _audioCodecCtx->sample_rate,
                _audioCodecCtx->sample_fmt,
                _audioCodecCtx->channels,
                _audioTimeBase,
                _swrContext ? @"resample" : @"");
    
    st = NULL;
    return cyPlayerErrorNone; 
}

- (cyPlayerError) openSubtitleStream: (NSInteger) subtitleStream
{
    AVCodecContext *codecCtx = avcodec_alloc_context3(NULL);
    avcodec_parameters_to_context(codecCtx, _formatCtx->streams[subtitleStream]->codecpar);
    
    AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
    if(!codec)
    {
        avcodec_free_context(&codecCtx);
        return cyPlayerErrorCodecNotFound;
    }
    
    const AVCodecDescriptor *codecDesc = avcodec_descriptor_get(codecCtx->codec_id);
    if (codecDesc && (codecDesc->props & AV_CODEC_PROP_BITMAP_SUB)) {
        // Only text based subtitles supported
        avcodec_free_context(&codecCtx);
        return cyPlayerErroUnsupported;
    }
    
    if (avcodec_open2(codecCtx, codec, NULL) < 0)
    {
        avcodec_free_context(&codecCtx);
        return cyPlayerErrorOpenCodec;
    }
    
    _subtitleStream = subtitleStream;
    _subtitleCodecCtx = codecCtx;
    
    LoggerStream(1, @"subtitle codec: '%s' mode: %d enc: %s",
                codecDesc->name,
                codecCtx->sub_charenc_mode,
                codecCtx->sub_charenc);
    
    _subtitleASSEvents = -1;
    
    if (codecCtx->subtitle_header_size) {
                
        NSString *s = [[NSString alloc] initWithBytes:codecCtx->subtitle_header
                                               length:codecCtx->subtitle_header_size
                                             encoding:NSASCIIStringEncoding];
        
        if (s.length) {
            
            NSArray *fields = [CYPlayerSubtitleASSParser parseEvents:s];
            if (fields.count && [fields.lastObject isEqualToString:@"Text"]) {
                _subtitleASSEvents = fields.count;
                LoggerStream(2, @"subtitle ass events: %@", [fields componentsJoinedByString:@","]);
            }
        }
    }
    
    return cyPlayerErrorNone;
}

-(void) closeFile
{
    dispatch_semaphore_wait([CYGCDManager sharedManager].av_read_frame_lock, DISPATCH_TIME_FOREVER);//加锁
    [self closeAudioStream];
    [self closeVideoStream];
    [self closeSubtitleStream];
//    [self closeFilter];
    
    _videoStreams = nil;
    _audioStreams = nil;
    _subtitleStreams = nil;
    
    if (_formatCtx) {
        
//        _formatCtx->interrupt_callback.opaque = NULL;
//        _formatCtx->interrupt_callback.callback = NULL;
        
        avformat_close_input(&_formatCtx);
    }
    
    if (_options)
    {
        av_dict_free(&_options);
    }
    
    _interruptCallback = nil;
    _isEOF = NO;
    dispatch_semaphore_signal([CYGCDManager sharedManager].av_read_frame_lock);//放行
}

- (void) closeFilter
{
    
    if (_validFilter)
    {
        _validFilter = NO;
        
        if (_buffersrc_ctx)
        {
            avfilter_free(_buffersrc_ctx);
            _buffersrc_ctx = NULL;
        }
        
        if (_buffersink_ctx)
        {
            avfilter_free(_buffersink_ctx);
            _buffersink_ctx = NULL;
        }
    }
    else
    {
        _buffersrc_ctx = NULL;
        _buffersink_ctx = NULL;
    }

}

- (void) closeVideoStream
{
    _videoStream = -1;
    
    [self closeScaler];
    
    if (_videoFrame) {
        av_frame_free(&_videoFrame);
        _videoFrame = NULL;
    }
    if (_videoFrame1) {
        av_frame_free(&_videoFrame1);
        _videoFrame1 = NULL;
    }
    if (_videoFrame2) {
        av_frame_free(&_videoFrame2);
        _videoFrame2 = NULL;
    }
    if (_videoFrame3) {
        av_frame_free(&_videoFrame3);
        _videoFrame3 = NULL;
    }
    if (_videoFrame4) {
        av_frame_free(&_videoFrame4);
        _videoFrame4 = NULL;
    }
    
    dispatch_semaphore_wait([CYGCDManager sharedManager].av_send_receive_packet_lock, DISPATCH_TIME_FOREVER);//加锁
    if (_videoCodecCtx) {
        avcodec_free_context(&_videoCodecCtx);
        _videoCodecCtx = NULL;
    }
    dispatch_semaphore_signal([CYGCDManager sharedManager].av_send_receive_packet_lock);
}

- (void) closeAudioStream
{
    _audioStream = -1;
        
    if (_swrBuffer) {
        
        free(_swrBuffer);
        _swrBuffer = NULL;
        _swrBufferSize = 0;
    }
    
    if (_swrContext) {
        
        swr_free(&_swrContext);
        _swrContext = NULL;
    }
        
    if (_audioFrame) {
        av_frame_free(&_audioFrame);
        _audioFrame = NULL;
    }
    if (_audioFrame1) {
        av_frame_free(&_audioFrame1);
        _audioFrame1 = NULL;
    }
    if (_audioFrame2) {
        av_frame_free(&_audioFrame2);
        _audioFrame2 = NULL;
    }
    if (_audioFrame3) {
        av_frame_free(&_audioFrame3);
        _audioFrame3 = NULL;
    }
    if (_audioFrame4) {
        av_frame_free(&_audioFrame4);
        _audioFrame4 = NULL;
    }
    
    if (_audioCodecCtx) {
        avcodec_free_context(&_audioCodecCtx);
        _audioCodecCtx = NULL;
    }
}

- (void) closeSubtitleStream
{
    _subtitleStream = -1;
    
    if (_subtitleCodecCtx) {
        
        avcodec_free_context(&_subtitleCodecCtx);
        _subtitleCodecCtx = NULL;
    }
}

-(NSString*)infoFilePath

{
    
    NSArray *Paths=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES );
    
    NSString *MyDocpath=[Paths objectAtIndex:0];

    return MyDocpath;
    
}



-(NSString *)currentTime{
    
    NSDate *currentDate = [NSDate date];
    
    NSDateFormatter *dateformatter=[[NSDateFormatter alloc] init];
    
    [dateformatter setDateFormat:@"YYYY-MM-dd mm:ss"];
    
    NSString *currentString=[dateformatter stringFromDate:currentDate];
    
    return currentString;
    
}



-(void)allWriteToFileWithLocalMac:(NSString *)localMac andRemoteMac:(NSString *)remoteMac andLength:(int)length{
    
    
    
    NSData *buffer;
    
    
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self infoFilePath]]) {
        
        
        
        NSLog(@"%@",@"文件不存在");
        
        NSString *s = [NSString stringWithFormat:@"开始了:\r"];
        
        [s writeToFile:[self infoFilePath] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        
        
    }
    
    
    
    NSString *filePath = [self infoFilePath];
    
    
    
    NSFileHandle  *outFile = [NSFileHandle fileHandleForWritingAtPath:filePath];
    
    
    
    if(outFile == nil)
        
    {
        
        NSLog(@"Open of file for writing failed");
        
    }
    
    
    
    //找到并定位到outFile的末尾位置(在此后追加文件)
    
    [outFile seekToEndOfFile];
    
    
    
    //读取inFile并且将其内容写到outFile中
    
    NSString *bs = [NSString stringWithFormat:@"发送数据时间:%@--localMac:%@--remoteMac:%@--length:%d \n",[self currentTime],localMac,remoteMac,length];
    
    buffer = [bs dataUsingEncoding:NSUTF8StringEncoding];
    
    
    
    [outFile writeData:buffer];
    
    
    
    //关闭读写文件
    
    [outFile closeFile];
    
}

- (CYSubtitleFrame *) handleSubtitle: (AVSubtitle *)pSubtitle
{
    NSMutableString *ms = [NSMutableString string];
    
    for (NSUInteger i = 0; i < pSubtitle->num_rects; ++i) {
       
        AVSubtitleRect *rect = pSubtitle->rects[i];
        if (rect) {
            
            if (rect->text) { // rect->type == SUBTITLE_TEXT
                
                NSString *s = [NSString stringWithUTF8String:rect->text];
                if (s.length) [ms appendString:s];
                
            } else if (rect->ass && _subtitleASSEvents != -1) {
                
                NSString *s = [NSString stringWithUTF8String:rect->ass];
                if (s.length) {
                    
                    NSArray *fields = [CYPlayerSubtitleASSParser parseDialogue:s numFields:_subtitleASSEvents];
                    if (fields.count && [fields.lastObject length]) {
                        
                        s = [CYPlayerSubtitleASSParser removeCommandsFromEventText: fields.lastObject];
                        if (s.length) [ms appendString:s];
                    }                    
                }
            }
        }
    }
    
    if (!ms.length)
        return nil;
    
    CYSubtitleFrame *frame = [[CYSubtitleFrame alloc] init];
    frame.text = [ms copy];   
    frame.position = pSubtitle->pts / AV_TIME_BASE + pSubtitle->start_display_time;
    frame.duration = (CGFloat)(pSubtitle->end_display_time - pSubtitle->start_display_time) / 1000.f;
    
#if 0
    LoggerStream(2, @"SUB: %.4f %.4f | %@",
          frame.position,
          frame.duration,
          frame.text);
#endif
    
    return frame;    
}

- (BOOL) interruptDecoder
{
    if (_interruptCallback)
        return _interruptCallback();
    return NO;
}

# pragma mark 解码核心

- (void) closeScaler
{
    if (_swsContext) {
        sws_freeContext(_swsContext);
        _swsContext = NULL;
    }
    
    if (_pictureValid) {
        cypicture_free(&_picture);
        _pictureValid = NO;
    }
    if (_pictureValid1) {
        cypicture_free(&_picture1);
        _pictureValid1 = NO;
    }
    if (_pictureValid2) {
        cypicture_free(&_picture2);
        _pictureValid2 = NO;
    }
    if (_pictureValid3) {
        cypicture_free(&_picture3);
        _pictureValid3 = NO;
    }
    if (_pictureValid4) {
        cypicture_free(&_picture4);
        _pictureValid4 = NO;
    }
}

- (BOOL) setupScalerWithPicture:(CYPicture *)picture isValid:(BOOL *)isValid Width:(int)width Heigth:(int)height DstFormat:(int)format
{
    [self closeScaler];
    
    *isValid = cypicture_alloc(picture,
                               format,
                               width,
                               height) == 0;
    if (!(*isValid))
        return NO;
    
    if (!_swsContext)
    {
        _swsContext = sws_getCachedContext(_swsContext,
                                           _videoCodecCtx->width,
                                           _videoCodecCtx->height,
                                           _videoCodecCtx->pix_fmt,
                                           width,
                                           height,
                                           format,
                                           SWS_FAST_BILINEAR,
                                           NULL, NULL, NULL);
    }
    
    
    return _swsContext != NULL;
}


/**
 获取视频方向, 1为横向, 2为纵向, 3为正方形
 
 @param videoCodecCtx videoCodecCtx
 @return  1为横向, 2为纵向, 3为正方形
 */
int video_direction(AVCodecContext *videoCodecCtx)
{
    CGFloat width = videoCodecCtx->width;
    CGFloat height = videoCodecCtx->height;
    
    if (width > height) {
        return 1;
    }else if (height > width) {
        return 2;
    }else if (width == height) {
        return 3;
    }else {
        return 0;
    }
}

void get_video_scale_max_size(AVCodecContext *videoCodecCtx, int * width, int * height)
{
    
    CGFloat scr_width = [UIScreen mainScreen].bounds.size.width * [UIScreen mainScreen].scale;
    CGFloat scr_height = [UIScreen mainScreen].bounds.size.height * [UIScreen mainScreen].scale;
//    CGFloat scr_width = [UIScreen mainScreen].bounds.size.width;
//    CGFloat scr_height = [UIScreen mainScreen].bounds.size.height;
    
    *width = videoCodecCtx->width;
    *height = videoCodecCtx->height;
    
    CGFloat ori_scale = round( ((CGFloat)(*width) / (CGFloat)(*height)) * 1000.0 ) / 1000.0;
    switch (video_direction(videoCodecCtx))
    {
        case 1://横向
        {
            if (*width > scr_height) {
                CGFloat scr_scale = round( (scr_height / scr_width) * 1000.0 ) / 1000.0;
                if (scr_scale < ori_scale)
                {
                    *width = scr_height;
                    *height = round(scr_height / ori_scale);
                }
                else if (scr_scale > ori_scale)
                {
                    *height = scr_width;
                    *width = round(scr_width * ori_scale);
                }
                else
                {
                    *width = scr_height;
                    *height = scr_width;
                }
            }
        }
            break;
        case 2://纵向
        {
            if (*width > scr_width) {
                CGFloat scr_scale = round( (scr_width / scr_height) * 1000.0 ) / 1000.0;
                
                if (scr_scale > ori_scale)
                {
                    *height = scr_height;
                    *width = round(scr_height * ori_scale);
                }
                else if (scr_scale < ori_scale)
                {
                    *width = scr_width;
                    *height = round(scr_width / ori_scale);
                }
                else
                {
                    *width = scr_width;
                    *height = scr_height;
                }
            }
        }
            break;
        case 3:
        {
            if (*width > scr_width) {
                *width = scr_width;
                *height = scr_width;
            }
        }
            break;
            
        default:
            break;
    }
}

- (CVPixelBufferRef)getCVPixelBufferRefWithAVFrame:(AVFrame *)frame
{
    CVReturn theError;
    if (!self->_pixelBufferPool){  //创建pixelBuffer缓存池，从缓存池中创建pixelBuffer以便复用
        NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
        [attributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
        [attributes setObject:[NSNumber numberWithInt:frame->width] forKey: (NSString*)kCVPixelBufferWidthKey];
        [attributes setObject:[NSNumber numberWithInt:frame->height] forKey: (NSString*)kCVPixelBufferHeightKey];
        [attributes setObject:@(frame->linesize[0]) forKey:(NSString*)kCVPixelBufferBytesPerRowAlignmentKey];
        [attributes setObject:[NSDictionary dictionary] forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
        theError = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef) attributes, &self->_pixelBufferPool);
        if (theError != kCVReturnSuccess){
            NSLog(@"CVPixelBufferPoolCreate Failed");
        }
    }
    
    CVPixelBufferRef pixelBuffer = nil;
    theError = CVPixelBufferPoolCreatePixelBuffer(NULL, self->_pixelBufferPool, &pixelBuffer);
    if(theError != kCVReturnSuccess){
        NSLog(@"CVPixelBufferPoolCreatePixelBuffer Failed");
    }

    theError = CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    if (theError != kCVReturnSuccess) {
        NSLog(@"lock error");
    }
    /*
     PixelBuffer中Y数据存放在Plane0中，UV数据存放在Plane1中，数据格式如下
     frame->data[0]  .........   YYYYYYYYY
     frame->data[1]  .........   UUUUUUUU
     frame->data[2]  .........   VVVVVVVVV
     PixelBuffer->Plane0 .......  YYYYYYYY
     PixelBuffer->Plane1 .......  UVUVUVUVUV
     所以需要把Y数据拷贝到Plane0上，把U和V数据交叉拷到Plane1上
     */
    size_t bytePerRowY = MIN(CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0), frame->width);
    size_t bytesPerRowUV = MIN(CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1) / 2, frame->width / 2);
    //获取Plane0的起始地址
    Byte* base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    memcpy(base, frame->data[0], bytePerRowY * frame->height);
    //获取Plane1的起始地址
    base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    uint32_t size = (uint32_t)bytesPerRowUV * frame->height / 2;
    //把UV数据交叉存储到dstData然后拷贝到Plane1上
    NSMutableData *dstNSData = [NSMutableData dataWithLength: 2 * size];
    Byte* dstData = dstNSData.mutableBytes;
    for (int i = 0; i < 2 * size; i++){
        if (i % 2 == 0){
            dstData[i] = frame->data[1][i/2];
        }else {
            dstData[i] = frame->data[2][i/2];
        }
    }
    memcpy(base, dstData, size * 2);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
//    CVPixelBufferRelease(pixelBuffer);
    return pixelBuffer;
    
}

- (BOOL)discardVideoFrameWithPosition:(CGFloat)position
                            OriginFPS:(CGFloat)o_fps
                      TargetFPS_Block:(CGFloat(^)(void))t_fps_block
{
    NSAssert(t_fps_block, @"error: t_fps_block is nil!");
    CGFloat t_fps = 0;
    if (t_fps_block) {
        t_fps = t_fps_block();
    }
    return [self discardVideoFrameWithPosition:position OriginFPS:o_fps TargetFPS:t_fps];
}


- (BOOL)discardVideoFrameWithPosition:(CGFloat)position
                            OriginFPS:(CGFloat)o_fps
                            TargetFPS:(CGFloat)t_fps
{
    if (o_fps <= t_fps || position == 0.0) {
        return NO;
    }
#ifdef DEBUG
//    NSLog(@"Dynamic FPS: %d", (int)t_fps);
#endif
    //符合降帧规则的帧,丢弃
    CGFloat discard_rate = (o_fps - t_fps) / o_fps;//(30 - 25) / 30  原有30fps的视频降帧到25fps,降帧率为1/6(六分之一)
    NSUInteger hashCount = (NSUInteger)(1 / discard_rate) + 1;
    
    NSUInteger position_index = (NSInteger)(position * o_fps);//计算出帧的位置
    
    NSUInteger hash = position_index % hashCount;
    
    if (hash == hashCount - 1) {
        return YES;
    }
    
    return NO;
}

- (CYVideoFrame *) handlePreviewImagesVideoFrame:(AVFrame *)videoFrame Picture:(CYPicture *)picture isPictureValid:(BOOL *)isPictureValid
{
    if (!videoFrame->data[0])
        return nil;
    
    CYVideoFrame *frame;
    
    CFAbsoluteTime startTime =CFAbsoluteTimeGetCurrent();
    
    CGFloat position = av_frame_get_best_effort_timestamp(videoFrame) * _videoTimeBase;
    CGFloat duration = 0.0;
    const int64_t frameDuration = av_frame_get_pkt_duration(videoFrame);
    if (frameDuration) {
        
        duration = frameDuration * _videoTimeBase; //* self.rate;
        duration += videoFrame->repeat_pict * _videoTimeBase * 0.5;
        
    } else {
        // sometimes, ffmpeg unable to determine a frame duration
        // as example yuvj420p stream from web camera
        duration = 1.0 / _fps;
    }
    
    
    int width = _videoCodecCtx->width;
    int height = _videoCodecCtx->height;
    if (!(_dstWidth > 0 && _dstHeight > 0))
    {
        get_video_scale_max_size(_videoCodecCtx, &width, &height);
        _dstWidth = width;
        _dstHeight = height;
    }
    else
    {
        width = _dstWidth;
        height = _dstHeight;
    }
    
    
    if (!_swsContext &&
        ![self setupScalerWithPicture:picture isValid:isPictureValid Width:width Heigth:height DstFormat:AV_PIX_FMT_RGB24]) {
        
        LoggerVideo(0, @"fail setup video scaler");
        return nil;
    }
    
    if (!(*isPictureValid)) {
        *isPictureValid = cypicture_alloc(picture,
                                          AV_PIX_FMT_RGB24,
                                          width,
                                          height) == 0;
        
        if (*isPictureValid == NO)
        {
            LoggerVideo(0, @"fail setup video picture");
            return nil;
        }
    }
    
    dispatch_semaphore_wait([CYGCDManager sharedManager].sws_context_lock, DISPATCH_TIME_FOREVER);
    sws_scale(_swsContext,
              (const uint8_t **)videoFrame->data,
              videoFrame->linesize,
              0,
              _videoCodecCtx->height,
              (*picture).data,
              (*picture).linesize);
    dispatch_semaphore_signal([CYGCDManager sharedManager].sws_context_lock);
    
    CYVideoFrameRGB *rgbFrame = [[CYVideoFrameRGB alloc] init];
    
    rgbFrame.linesize = (*picture).linesize[0];
    rgbFrame.rgb = [NSData dataWithBytes:(*picture).data[0]
                                  length:rgbFrame.linesize * height];
    frame = rgbFrame;
    
    frame.width = width;
    frame.height = height;
    frame.position = position;
    frame.duration = duration;
    CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
    //NSLog(@"Linked handleVideoFrame in %f ms", linkTime *1000.0);
#if 0
    LoggerVideo(2, @"VFD: %.4f %.4f | %lld ",
                frame.position,
                frame.duration,
                av_frame_get_pkt_pos(videoFrame));
    
//    CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
    //NSLog(@"Linked in %f ms", linkTime *1000.0);
#endif
    
    return frame;
}

- (CYVideoFrame *) handleVideoFrame:(AVFrame *)videoFrame Picture:(CYPicture *)picture isPictureValid:(BOOL *)isPictureValid
{
    if (!videoFrame->data[0])
        return nil;
    
    CYVideoFrame *frame;
    
    CFAbsoluteTime startTime =CFAbsoluteTimeGetCurrent();
    
    CGFloat position = av_frame_get_best_effort_timestamp(videoFrame) * _videoTimeBase;
    CGFloat duration = 0.0;
    __weak typeof(&*self)weakSelf = self;
    if ([self discardVideoFrameWithPosition:position OriginFPS:_fps TargetFPS_Block:^CGFloat{
        if (weakSelf.dynamicFPS_Block) {
            return weakSelf.dynamicFPS_Block();
        }else {
            return CYPlayerDecoderMaxFPS * weakSelf.rate;
        }
    }]) {
        return nil;
    }
    
    const int64_t frameDuration = av_frame_get_pkt_duration(videoFrame);
    if (frameDuration) {
        
        duration = frameDuration * _videoTimeBase; //* self.rate;
        duration += videoFrame->repeat_pict * _videoTimeBase * 0.5;
        
    } else {
        // sometimes, ffmpeg unable to determine a frame duration
        // as example yuvj420p stream from web camera
        duration = 1.0 / _fps;
    }
    
    //判断是否丢弃帧
    if ( _fps >= CYPlayerDecoderMaxFPS * self.rate)
    {
        CGFloat fps_scale =  _fps / (CYPlayerDecoderMaxFPS / self.rate) ;
        
        duration *= fps_scale;//更新降帧之后的每帧时延 例如30fps,降为25,则时延有0.3333增加为0.3846
        
    }
    
    if ((_position > position) &&
        _position != 0)
    {
        switch (_videoFrameFormat) {
            case CYVideoFrameFormatYUV:
            {
                frame = [[CYVideoFrameYUV alloc] init];
                frame.position = position;
                frame.duration = duration;
//                CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
                //NSLog(@"Linked handleVideoFrame in %f ms", linkTime *1000.0);
            }
                return nil;
                
            default:
            {
                frame = [[CYVideoFrameRGB alloc] init];
                frame.position = position;
                frame.duration = duration;
//                CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
                //NSLog(@"Linked handleVideoFrame in %f ms", linkTime *1000.0);
            }
                return nil;;
        }
    }
    
    
    
    int width = _videoCodecCtx->width;
    int height = _videoCodecCtx->height;
    if (!(_dstWidth > 0 && _dstHeight > 0))
    {
        get_video_scale_max_size(_videoCodecCtx, &width, &height);
        _dstWidth = width;
        _dstHeight = height;
    }
    else
    {
        width = _dstWidth;
        height = _dstHeight;
    }
    
    if (_videoFrameFormat == CYVideoFrameFormatYUV)
    {
        if (_videoCodecCtx->width != width)//宽高发生了改变
        {
            if (!_swsContext &&
                ![self setupScalerWithPicture:picture isValid:isPictureValid Width:width Heigth:height DstFormat:_videoCodecCtx->pix_fmt]) {
                
                LoggerVideo(0, @"fail setup video scaler");
                return nil;
            }
            
            if (!(*isPictureValid)) {
                *isPictureValid = cypicture_alloc(picture,
                                                  _videoCodecCtx->pix_fmt,
                                                  width,
                                                  height) == 0;
                
                if (*isPictureValid == NO)
                {
                    LoggerVideo(0, @"fail setup video picture");
                    return nil;
                }
            }
            //            const int lineSize[8]  = { width, width / 2, width / 2, 0, 0, 0, 0, 0 };
            
            
            //在这写入要计算时间的代码
            dispatch_semaphore_wait([CYGCDManager sharedManager].sws_context_lock, DISPATCH_TIME_FOREVER);
            sws_scale(_swsContext,
                      (const uint8_t **)videoFrame->data,
                      videoFrame->linesize,
                      0,
                      videoFrame->height,
                      picture->data,
                      picture->linesize);
            dispatch_semaphore_signal([CYGCDManager sharedManager].sws_context_lock);
            
            CYVideoFrameYUV * yuvFrame = [[CYVideoFrameYUV alloc] init];
            
//            if (@available(iOS 8.0, *))
//            {
//                yuvFrame.pixelBuffer = [self getCVPixelBufferRefWithAVFrame:videoFrame];
//            }
//            else
            {
                yuvFrame.luma = copyFrameData((*picture).data[0],
                                              (*picture).linesize[0],
                                              width,
                                              height);
                
                yuvFrame.chromaB = copyFrameData((*picture).data[1],
                                                 (*picture).linesize[1],
                                                 width / 2,
                                                 height / 2);
                
                yuvFrame.chromaR = copyFrameData((*picture).data[2],
                                                 (*picture).linesize[2],
                                                 width / 2,
                                                 height / 2);
                struct CYPixelBufferBytesPerRowOfPlane p = {width, width / 2.0, width / 2.0};
                yuvFrame.bytesPerRowOfPlans = p;
            }
            
            frame = yuvFrame;
            
            
            
        }
        else
        {
            CYVideoFrameYUV * yuvFrame = [[CYVideoFrameYUV alloc] init];
            
//            if (@available(iOS 8.0, *))
//            {
//                yuvFrame.pixelBuffer = [self getCVPixelBufferRefWithAVFrame:videoFrame];
//            }
//            else
            {
                yuvFrame.luma = copyFrameData(videoFrame->data[0],
                                              videoFrame->linesize[0],
                                              width,
                                              height);
                
                yuvFrame.chromaB = copyFrameData(videoFrame->data[1],
                                                 videoFrame->linesize[1],
                                                 width / 2,
                                                 height / 2);
                
                yuvFrame.chromaR = copyFrameData(videoFrame->data[2],
                                                 videoFrame->linesize[2],
                                                 width / 2,
                                                 height / 2);
                struct CYPixelBufferBytesPerRowOfPlane p = {width, width / 2.0, width / 2.0};
                yuvFrame.bytesPerRowOfPlans = p;
            }
            
            frame = yuvFrame;
            
            
        }
        
        
    }
    else
    {
        
        if (!_swsContext &&
            ![self setupScalerWithPicture:picture isValid:isPictureValid Width:width Heigth:height DstFormat:AV_PIX_FMT_RGB24]) {
            
            LoggerVideo(0, @"fail setup video scaler");
            return nil;
        }
        
        if (!(*isPictureValid)) {
            *isPictureValid = cypicture_alloc(picture,
                                              AV_PIX_FMT_RGB24,
                                              width,
                                              height) == 0;
            
            if (*isPictureValid == NO)
            {
                LoggerVideo(0, @"fail setup video picture");
                return nil;
            }
        }
        
        dispatch_semaphore_wait([CYGCDManager sharedManager].sws_context_lock, DISPATCH_TIME_FOREVER);
        sws_scale(_swsContext,
                  (const uint8_t **)videoFrame->data,
                  videoFrame->linesize,
                  0,
                  _videoCodecCtx->height,
                  (*picture).data,
                  (*picture).linesize);
        dispatch_semaphore_signal([CYGCDManager sharedManager].sws_context_lock);
        
        CYVideoFrameRGB *rgbFrame = [[CYVideoFrameRGB alloc] init];
        
        rgbFrame.linesize = (*picture).linesize[0];
        rgbFrame.rgb = [NSData dataWithBytes:(*picture).data[0]
                                      length:rgbFrame.linesize * height];
        frame = rgbFrame;
    }
    
    frame.width = width;
    frame.height = height;
    frame.position = position;
    frame.duration = duration;
    CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
    //NSLog(@"Linked handleVideoFrame in %f ms", linkTime *1000.0);
#if 0
    LoggerVideo(2, @"VFD: %.4f %.4f | %lld ",
                frame.position,
                frame.duration,
                av_frame_get_pkt_pos(videoFrame));
    
//    CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
    //NSLog(@"Linked in %f ms", linkTime *1000.0);
#endif
    
    return frame;
}


/**
 初始化转换参数
 
 @param swr_ctx SwrContext 转换参数
 @param codec AVCodecContext
 */
int audio_swr_resampling_audio_init(SwrContext **swr_ctx, AVCodecContext *codec, CGFloat rate)
{
    //    if(codec->sample_fmt == AV_SAMPLE_FMT_S16 || codec->sample_fmt == AV_SAMPLE_FMT_S32 ||codec->sample_fmt == AV_SAMPLE_FMT_U8){
    //
    //        LoggerAudio(1, @"codec->sample_fmt:%d", codec->sample_fmt);
    //
    //        if(*swr_ctx){
    //
    //            swr_free(swr_ctx);
    //
    //            *swr_ctx = NULL;
    //        }
    //        return 2;
    //    }
    
    if(*swr_ctx){
        swr_free(swr_ctx);
    }
    
    *swr_ctx = swr_alloc();
    
    if(!*swr_ctx){
        
        LoggerAudio(1, @"%@",@"swr_alloc failed");
        
        return -1;
        
    }
    
    if (codec == NULL) { LoggerAudio(1, @"%@",@"codec failed"); return -1; }
    
#ifdef USE_OPENAL
    CYPCMAudioManager * audioManager = [CYPCMAudioManager audioManager];
#endif
#ifdef USE_AUDIOTOOL
    id<CYAudioManager> audioManager = [CYAudioManager audioManager];
//    *swr_ctx = swr_alloc_set_opts(NULL,
//                                    av_get_default_channel_layout(audioManager.numOutputChannels),
//                                    AV_SAMPLE_FMT_S16,
//                                    audioManager.samplingRate,
//                                    av_get_default_channel_layout(codec->channels),
//                                    codec->sample_fmt,
//                                    codec->sample_rate,
//                                    0,
//                                    NULL);
#endif
    /* set options */
    
    if (codec->channel_layout)
    {
        av_opt_set_int(*swr_ctx, "in_channel_layout",    codec->channel_layout, 0);
    }
    else
    {
        av_opt_set_int(*swr_ctx, "in_channel_layout",    av_get_default_channel_layout(codec->channels), 0);
    }

    av_opt_set_int(*swr_ctx, "in_sample_rate",       codec->sample_rate, 0);

    av_opt_set_sample_fmt(*swr_ctx, "in_sample_fmt", codec->sample_fmt, 0);

    av_opt_set_int(*swr_ctx, "out_channel_layout",    av_get_default_channel_layout((int)(audioManager.avcodecContextNumOutputChannels)), 0);

    av_opt_set_int(*swr_ctx, "out_sample_rate",       audioManager.avcodecContextSamplingRate, 0);

    av_opt_set_sample_fmt(*swr_ctx, "out_sample_fmt", AV_SAMPLE_FMT_S16, 0);// AV_SAMPLE_FMT_S16
    
    /* initialize the resampling context */
    
    int ret = 0;
    
    if ((ret = swr_init(*swr_ctx)) < 0) {
        
        LoggerAudio(1, @"Failed to initialize the resampling context\n");
        
        if(*swr_ctx){
            
            swr_free(swr_ctx);
            
            *swr_ctx = NULL;
            
        }
        
        return ret;
        
    }
    
    return 1;
    
}


int audio_swr_resampling_audio(SwrContext *swr_ctx, AVFrame *audioFrame, uint8_t **targetData, CGFloat ratio, CGFloat rate){
    
    int len = swr_convert(swr_ctx,
                          targetData,
                          audioFrame->nb_samples * ratio,
                          (const uint8_t **)audioFrame->data,
                          audioFrame->nb_samples);
    
    if(len < 0){
        
        LoggerAudio(0, @"error swr_convert");
        
        return -1;
        
    }
#ifdef USE_OPENAL
    CYPCMAudioManager * audioManager = [CYPCMAudioManager audioManager];
#endif
    
#ifdef USE_AUDIOTOOL
    id<CYAudioManager> audioManager = [CYAudioManager audioManager];
#endif
    
    long int dst_bufsize = len * audioManager.avcodecContextNumOutputChannels * av_get_bytes_per_sample(AV_SAMPLE_FMT_S16);
    
    //    LoggerAudio(1, @" dst_bufsize:%d", (int)dst_bufsize);
    
    return (int)dst_bufsize;
}

void audio_swr_resampling_audio_destory(SwrContext **swr_ctx){
    
    if(*swr_ctx){
        
        swr_free(swr_ctx);
        
        *swr_ctx = NULL;
    }
}

- (CYAudioFrame *) handleAudioFrame:(AVFrame *)audioFrame
{
    if (!audioFrame->data[0])
        return nil;
    
    CFAbsoluteTime startTime =CFAbsoluteTimeGetCurrent();
    
#ifdef USE_OPENAL
    CYPCMAudioManager * audioManager = [CYPCMAudioManager audioManager];
    const NSUInteger numChannels = audioManager.avcodecContextNumOutputChannels;
#endif
#ifdef USE_AUDIOTOOL
    id<CYAudioManager> audioManager = [CYAudioManager audioManager];
    const NSUInteger numChannels = audioManager.avcodecContextNumOutputChannels;
#endif
    
    CGFloat position = av_frame_get_best_effort_timestamp(audioFrame) * _audioTimeBase; //* self.rate;
    CGFloat duration = av_frame_get_pkt_duration(audioFrame) * _audioTimeBase; //* self.rate;
    
    duration *= self.rate;
    
    NSInteger numFrames;
    
    void * audioData;
    int out_linesize;
    
    const NSUInteger ratio = MAX(1, audioManager.avcodecContextSamplingRate / _audioCodecCtx->sample_rate) * MAX(1, audioManager.avcodecContextNumOutputChannels / _audioCodecCtx->channels) * 2;
    
    const int bufSize = av_samples_get_buffer_size(&out_linesize,
                                                   (int)audioManager.avcodecContextNumOutputChannels,
                                                   (int)(audioFrame->nb_samples * ratio),
                                                   AV_SAMPLE_FMT_S16,
                                                   1);
    
    dispatch_semaphore_wait([CYGCDManager sharedManager].swr_context_lock, DISPATCH_TIME_FOREVER);
    if (_swrContext) {
 
        if (!_swrBuffer || _swrBufferSize < bufSize) {
            _swrBufferSize = bufSize;
            _swrBuffer = realloc(_swrBuffer, _swrBufferSize);
        }
        
        
        
        Byte *outbuf[2] = { _swrBuffer, 0 };
        
        numFrames = audio_swr_resampling_audio(_swrContext, audioFrame, outbuf, ratio, _rate);
#ifdef USE_AUDIOTOOL
        numFrames /=  av_get_bytes_per_sample(AV_SAMPLE_FMT_S16);
#endif
        
        //        //存储PCM数据，注意：m_SwrCtx即使进行了转换，也要判断转换后的数据是否分平面
        //        if (_swrContext ) {
        //            NSString *filename=[[self infoFilePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld.pcm", _fileCount]];
        //            const char *out_file = [filename cStringUsingEncoding:NSUTF8StringEncoding];
        //            if (!_out_fb)
        //            {
        //                _out_fb = fopen(out_file, "wb");
        //            }
        //            size_t size = fwrite(outbuf[0], 1, bufSize, _out_fb);
        //            fclose(_out_fb);
        //            //            _fileCount++;
        //        }
        
        if (numFrames < 0) {
            LoggerAudio(0, @"fail resample audio");
            return nil;
        }
        audioData = _swrBuffer;
        
    } else {
        
        if (_audioCodecCtx->sample_fmt != AV_SAMPLE_FMT_S16) {
            NSAssert(false, @"bucheck, audio format is invalid");
            return nil;
        }
        
        audioData = audioFrame->extended_data;
        numFrames = out_linesize;
    }
    dispatch_semaphore_signal([CYGCDManager sharedManager].swr_context_lock);
    
#ifdef USE_AUDIOTOOL
    const NSUInteger numElements = numFrames;
    NSMutableData *data = [NSMutableData dataWithLength:numElements * sizeof(float)];
    float scale = 1.0 / (float)INT16_MAX ;
    vDSP_vflt16((SInt16 *)audioData, 1, data.mutableBytes, 1, numElements);
    vDSP_vsmul(data.mutableBytes, 1, &scale, data.mutableBytes, 1, numElements);
    
    CYAudioFrame *frame = [[CYAudioFrame alloc] init];
    frame.samples = data;
#endif
    
#ifdef USE_OPENAL
    CYAudioFrame *frame = [[CYAudioFrame alloc] init];
    frame.samples = [NSData dataWithBytes:audioData length:numFrames];
#endif
    
    if (duration == 0) {
        // sometimes ffmpeg can't determine the duration of audio frame
        // especially of wma/wmv format
        // so in this case must compute duration
        duration = frame.samples.length / (sizeof(float) * numChannels * audioManager.avcodecContextSamplingRate);
    }
    frame.position = position;
    frame.duration = duration;
    
#if 0
    LoggerAudio(2, @"AFD: %.4f %.4f | %.4f ",
                frame.position,
                frame.duration,
                frame.samples.length / (8.0 * 44100.0));
#endif
    CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
    //NSLog(@"Linked handleAudioFrame in %f ms", linkTime *1000.0);
    return frame;
}

- (void) asyncDecodeFrames:(CGFloat)minDuration audioFrame:(AVFrame *)audioFrame videoFrame:(AVFrame *)videoFrame picture:(CYPicture *)picture isPictureValid:(BOOL *)isPictureValid compeletionHandler:(CYPlayerCompeletionThread)compeletion
{
    __weak typeof(&*self)weakSelf = self;
    dispatch_group_async([CYGCDManager sharedManager].concurrent_group, [CYGCDManager sharedManager].concurrent_decode_queue, ^{
//
//    })
//    dispatch_async(_concurrentDecodeQueue, ^{
        __strong typeof(&*weakSelf)strongSelf = weakSelf;
        
        if (!strongSelf) { return; }
        NSMutableArray *result = [NSMutableArray array];
        
        AVPacket * packet = av_packet_alloc();
        
        CGFloat decodedDuration = 0;
        
        BOOL finished = NO;
        CGFloat curr_targetPos = weakSelf.targetPosition;
        while (!finished && strongSelf->_formatCtx && curr_targetPos == weakSelf.targetPosition) {
//            NSLog(@"%f", curr_targetPos);
            
            dispatch_semaphore_wait([CYGCDManager sharedManager].av_read_frame_lock, DISPATCH_TIME_FOREVER);//加锁
            
//            CFAbsoluteTime startTime =CFAbsoluteTimeGetCurrent();
            ///读取下一帧开始
            if (av_read_frame(strongSelf->_formatCtx, packet) < 0) {
                strongSelf->_isEOF = YES;
                av_packet_unref(packet);
                dispatch_semaphore_signal([CYGCDManager sharedManager].av_read_frame_lock);//放行
                break;
            }
//             CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
#ifdef DEBUG
//            NSLog(@"av_read_frame in %.2f ms", linkTime * 1000.0);
#endif
            
            dispatch_semaphore_signal([CYGCDManager sharedManager].av_read_frame_lock);//放行
            
            CYPlayerFrame * frame = [weakSelf handlePacket:packet audioFrame:audioFrame videoFrame:videoFrame picture:picture isPictureValid:isPictureValid];
//            NSLog(@"objc对象实际分配的内存大小: %zd", malloc_size((__bridge const void *)(frame)));

            if ([frame isKindOfClass:[CYVideoFrameYUV class]]) {
                CGFloat yL = ((CYVideoFrameYUV *)frame).luma.length / 1024.0 / 1024.0;
                CGFloat uL = ((CYVideoFrameYUV *)frame).chromaR.length / 1024.0 / 1024.0;
                CGFloat vL = ((CYVideoFrameYUV *)frame).chromaB.length / 1024.0 / 1024.0;
                #ifdef DEBUG
//                NSLog(@"Data Length: Y: %.2f MB, U: %.2fMB, V: %.2fMB", yL, uL, vL);
                #endif
                if (yL <= 0 || uL <= 0 || vL <= 0) {
                    av_packet_unref(packet);
                    continue;
                }
            }

            
            if (frame)
            {
                [result addObject:frame];
                if (strongSelf->_videoStream == -1) {
                    if (frame.position >= strongSelf->_position)
                    {
                        strongSelf->_position = strongSelf->_position + frame.duration;
                        decodedDuration += frame.duration;
                    }
                    if (decodedDuration > minDuration)
                        finished = YES;
                }
                else
                {
                    if (frame.type == CYPlayerFrameTypeVideo)
                    {
                        if (frame.position >= strongSelf->_position)
                        {
                            strongSelf->_position = strongSelf->_position + frame.duration;
                            decodedDuration += frame.duration;
                        }
                    }
                    
                    if (decodedDuration > minDuration)
                        finished = YES;
                }
            }
            
            
            av_packet_unref(packet);
        }
        
        if (curr_targetPos == weakSelf.targetPosition)
        {
            compeletion(result);
        }
        else
        {
            NSLog(@"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA");
            compeletion(nil);
        }
        
        av_packet_free(&packet);
    });
}

//AVHWAccel *ff_find_hwaccel(enum AVCodecID codec_id, enum AVPixelFormat pix_fmt)
//{
//    AVHWAccel *hwaccel=NULL;
//
//    while((hwaccel= av_hwaccel_next(hwaccel))){
//        NSLog(@"name:%s type:%d id:%u pix:%d",hwaccel->name,hwaccel->type,hwaccel->id,hwaccel->pix_fmt);
//        if (   hwaccel->id      == codec_id
//            && hwaccel->pix_fmt == pix_fmt)
//            return hwaccel;
//    }
//    return NULL;
//}

# pragma mark 滤镜 AVFilter
int filters_init(AVFormatContext *ifmt_ctx,
                  AVFilterContext **buffersrc_ctx,
                  AVFilterContext **buffersink_ctx,
                  int filer_type)
{
    AVFilter *buffersrc  = avfilter_get_by_name("buffer");
    AVFilter *buffersink = avfilter_get_by_name("buffersink");
    NSString *image_path = [[NSBundle mainBundle] pathForResource:@"logo" ofType:@"png"];
    NSString * filter_watermark_tmp = [NSString stringWithFormat:@"movie=%@[watermark];[in][watermark]overlay=100:100",image_path];
    
    char args[512];
    int ret;
    AVFilterInOut *outputs = avfilter_inout_alloc();
    if (!outputs)
    {
        printf("Cannot alloc output\n");
        ret = -1;
        goto error;
    }
    AVFilterInOut *inputs = avfilter_inout_alloc();
    if (!inputs)
    {
        printf("Cannot alloc input\n");
        ret = -1;
        goto error;
    }
    
    AVFilterGraph *filter_graph = NULL;
    if (filter_graph)
        avfilter_graph_free(&filter_graph);
    filter_graph = avfilter_graph_alloc();
    if (!filter_graph)
    {
        printf("Cannot create filter graph\n");
        ret = -1;
        goto error;
    }
    AVStream * video_Stream = ifmt_ctx->streams[0];
    AVCodecContext *codecCtx = avcodec_alloc_context3(NULL);
    avcodec_parameters_to_context(codecCtx, video_Stream->codecpar);
    /* buffer video source: the decoded frames from the decoder will be inserted here. */
    snprintf(args, sizeof(args),
             "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d",
             codecCtx->width, codecCtx->height, codecCtx->pix_fmt,
             ifmt_ctx->streams[0]->time_base.num, ifmt_ctx->streams[0]->time_base.den,
             codecCtx->sample_aspect_ratio.num, codecCtx->sample_aspect_ratio.den);
    
    ret = avfilter_graph_create_filter(buffersrc_ctx,
                                       buffersrc,
                                       "in",
                                       args,
                                       NULL,
                                       filter_graph);
    if (ret < 0) {
        printf("Cannot create buffer source\n");
        goto error;
    }
    
    /* buffer video sink: to terminate the filter chain. */
    ret = avfilter_graph_create_filter(buffersink_ctx,
                                       buffersink,
                                       "out",
                                       NULL,
                                       NULL,
                                       filter_graph);
    if (ret < 0) {
        printf("Cannot create buffer sink\n");
        goto error;
    }
    
    /* Endpoints for the filter graph. */
    outputs->name = av_strdup("in");
    outputs->filter_ctx = *buffersrc_ctx;
    outputs->pad_idx = 0;
    outputs->next = NULL;
    
    inputs->name = av_strdup("out");
    inputs->filter_ctx = *buffersink_ctx;
    inputs->pad_idx = 0;
    inputs->next = NULL;
    
    
    const char *filter_descr = "null";
    const char *filter_mirror = "crop=iw/2:ih:0:0,split[left][tmp];[tmp]hflip[right];[left]pad=iw*2[a];[a][right]overlay=w";
    const char *filter_watermark = [filter_watermark_tmp cStringUsingEncoding:NSUTF8StringEncoding];//"movie=logo.png[wm];[in][wm]overlay=5:5[out]";
    const char *filter_negate = "negate[out]";
    const char *filter_edge = "edgedetect[out]";
    const char *filter_split4 = "scale=iw/2:ih/2[in_tmp];[in_tmp]split=4[in_1][in_2][in_3][in_4];[in_1]pad=iw*2:ih*2[a];[a][in_2]overlay=w[b];[b][in_3]overlay=0:h[d];[d][in_4]overlay=w:h[out]";
    const char *filter_vintage = "curves=vintage";
    const char *filter_brightness = "eq=brightness=0.5[out] ";    //亮度。The value must be a float value in range -1.0 to 1.0. The default value is "0".
    const char *filter_contrast = "eq=contrast=1.5[out] ";        //对比度。The value must be a float value in range -2.0 to 2.0. The default value is "1".
    const char *filter_saturation = "eq=saturation=1.5[out] ";    //饱和度。The value must be a float in range 0.0 to 3.0. The default value is "1".
    //const char *filter_eq = "eq=contrast=1.0:brightness=-0.0:saturation=1.0 ";
    char filter_eq[512];
    float t_brightness_value = 1 ;//range:(-2)to(2)
    float t_contrast_value = 1 ;//range:(-2)to(2)
    float t_saturation_value = 1 ;//range:(-2)to(2)
    snprintf(filter_eq, sizeof(filter_eq), "eq=brightness=%f:contrast=%f:saturation=%f", t_brightness_value, t_contrast_value, t_saturation_value);
    printf("eq=brightness=%f:contrast=%f:saturation=%f \n", t_brightness_value, t_contrast_value, t_saturation_value);
    
    int x = 50 ;
    int y = 60 ;
    int iWidth = 300 ;
    int iHeight = 300 ;
    char filter_test[512];
    snprintf(filter_test, sizeof(filter_test), "[in]split[ori][tmp];[tmp]crop=%d:%d:%d:%d,eq=brightness=%f:contrast=%f:saturation=%f[eq_enhance];[ori][eq_enhance]overlay=%d:%d[out]",
             iWidth, iHeight, x, y, t_brightness_value, t_contrast_value, t_saturation_value, x, y);
    
    switch(filer_type)
    {
        case CYPlayerFilter_FILTER_NULL:
            filter_descr = "null";
            break;
        case CYPlayerFilter_FILTER_MIRROR:
            filter_descr = filter_mirror;
            break;
        case CYPlayerFilter_FILTER_WATERMARK:
            filter_descr = filter_watermark;
            break;
        case CYPlayerFilter_FILTER_NEGATE:
            filter_descr = filter_negate;
            break;
        case CYPlayerFilter_FILTER_EDGE:
            filter_descr = filter_edge;
            break;
        case CYPlayerFilter_FILTER_SPLIT4:
            filter_descr = filter_split4;
            break;
        case CYPlayerFilter_FILTER_VINTAGE:
            filter_descr = filter_vintage;
            break;
        case CYPlayerFilter_FILTER_BRIGHTNESS:
            filter_descr = filter_brightness;
            break;
        case CYPlayerFilter_FILTER_CONTRAST:
            filter_descr = filter_contrast;
            break;
        case CYPlayerFilter_FILTER_SATURATION:
            filter_descr = filter_saturation;
            break;
        case CYPlayerFilter_FILTER_EQ:
            filter_descr = filter_eq;
            break;
        case CYPlayerFilter_FILTER_TEST:
            filter_descr = filter_test;
            break;
        default:
            break;
    }
//    filter_descr = "setpts=0.5*PTS";
//    filter_descr = "[0:v]setpts=0.5*PTS[v];[0:a]atempo=2.0[a]";
//    filter_descr = filter_test;
//    filter_descr = "split [main][tmp]; [tmp] crop=iw:ih/2:0:0, vflip [flip]; [main][flip] overlay=0:H/2:enable='between(t,0,15)'";
    if ((ret = avfilter_graph_parse_ptr(filter_graph, filter_descr,
                                        &inputs, &outputs, NULL)) < 0)
        goto error;
    
    if ((ret = avfilter_graph_config(filter_graph, NULL)) < 0)
        goto error;
    
    avfilter_inout_free(&inputs);
    avfilter_inout_free(&outputs);
    avcodec_free_context(&codecCtx);
    
    return 0;
    
error:
    avfilter_inout_free(&inputs);
    avfilter_inout_free(&outputs);
    avcodec_free_context(&codecCtx);
    avfilter_graph_free(&filter_graph);
    return ret;
}

#pragma mark - public
- (CYHardwareDecompressVideo *)hwDecompressor
{
    if (!_hwDecompressor && self.validVideo && _videoCodecCtx->codec_id == AV_CODEC_ID_H264)
    {
        _hwDecompressor = [[CYHardwareDecompressVideo alloc] initWithCodecCtx:_videoCodecCtx];
    }
    return _hwDecompressor;
}

- (void)setUseHWDecompressor:(BOOL)useHWDecompressor
{
    _useHWDecompressor = useHWDecompressor;
}

- (void)setRate:(CGFloat)rate
{
    _rate = 1 / rate;
#ifdef USE_OPENAL
    [[CYPCMAudioManager audioManager] setPlayRate: rate];
#endif
#ifdef USE_AUDIOTOOL
    [[CYSonicManager sonicManager] setPlaySpeed:rate];
#endif
//    dispatch_semaphore_wait([CYGCDManager sharedManager].swr_context_lock, DISPATCH_TIME_FOREVER);
//    BOOL result = audio_swr_resampling_audio_init(&_swrContext, _audioCodecCtx, rate);
//    if (result)
//    {
//        _rate = 1 / rate;
//        [[CYPCMAudioManager audioManager] setPlayRate: rate];
//    }
//    dispatch_semaphore_signal([CYGCDManager sharedManager].swr_context_lock);
}

- (BOOL) setupVideoFrameFormat: (CYVideoFrameFormat) format
{
    if (format == CYVideoFrameFormatYUV &&
        _videoCodecCtx &&
        (_videoCodecCtx->pix_fmt == AV_PIX_FMT_YUV420P || _videoCodecCtx->pix_fmt == AV_PIX_FMT_YUVJ420P)) {
        
        _videoFrameFormat = CYVideoFrameFormatYUV;
        return YES;
    }
    
    _videoFrameFormat = CYVideoFrameFormatRGB;
    return _videoFrameFormat == format;
}

- (CYVideoFrameFormat)getVideoFrameFormat
{
    return _videoFrameFormat;
}


- (void) new_asyncDecodeFrames:(CGFloat)minDuration targetPosition:(CGFloat)targetPos compeletionHandler:(CYPlayerCompeletionDecode)compeletion
{
    [self asyncDecodeFrames:minDuration audioFrame:_audioFrame videoFrame:_videoFrame picture:&_picture isPictureValid:&_pictureValid compeletionHandler:^(NSArray<CYPlayerFrame *> *frames) {
        NSMutableArray * result = [[NSMutableArray alloc] initWithCapacity:200];
        for (CYPlayerFrame * frame in frames)
        {
            if (frame.position >= targetPos)
            {
                [result addObject:frame];
            }
        }
        compeletion(result, YES);
    }];
}

- (void) asyncDecodeFrames:(CGFloat)minDuration targetPosition:(CGFloat)targetPos compeletionHandler:(CYPlayerCompeletionDecode)compeletion
{
    if (_videoStream == -1 &&
        _audioStream == -1)
        return;
//    self.targetPosition = targetPos;
    __weak typeof(&*self)weakSelf = self;
    __block NSInteger compeletedConter = 0;
    NSInteger threadCount = 2; //CYPlayerDecoderConCurrentThreadCount
    for (int i = 0; i < threadCount; i++)//同时开多了容易造成decoder结束, 以及网络差的情况下接口延迟大
    {
        switch (i) {
            case 0:
            {
                [self asyncDecodeFrames:minDuration audioFrame:_audioFrame videoFrame:_videoFrame picture:&_picture isPictureValid:&_pictureValid compeletionHandler:^(NSArray<CYPlayerFrame *> *frames) {
                    NSMutableArray * result = [[NSMutableArray alloc] initWithCapacity:20];
                    for (CYPlayerFrame * frame in frames)
                    {
                        if (frame.position >= targetPos)
                        {
                            [result addObject:frame];
                        }
                    }
                    compeletedConter++;
                    compeletion(result, compeletedConter == threadCount);
                }];
            }
                break;
            case 1:
            {
                [self asyncDecodeFrames:minDuration audioFrame:_audioFrame1 videoFrame:_videoFrame1 picture:&_picture1 isPictureValid:&_pictureValid1 compeletionHandler:^(NSArray<CYPlayerFrame *> *frames) {
                    NSMutableArray * result = [[NSMutableArray alloc] initWithCapacity:20];
                    for (CYPlayerFrame * frame in frames)
                    {
                        if (frame.position >= targetPos)
                        {
                            [result addObject:frame];
                        }
                    }
                    compeletedConter++;
                    compeletion(result, compeletedConter == threadCount);
                }];
            }
                break;
            case 2:
            {
                [self asyncDecodeFrames:minDuration audioFrame:_audioFrame2 videoFrame:_videoFrame2 picture:&_picture2 isPictureValid:&_pictureValid2 compeletionHandler:^(NSArray<CYPlayerFrame *> *frames) {
                    NSMutableArray * result = [[NSMutableArray alloc] initWithCapacity:20];
                    for (CYPlayerFrame * frame in frames)
                    {
                        if (frame.position >= targetPos)
                        {
                            [result addObject:frame];
                        }
                    }
                    compeletedConter++;
                    compeletion(result, compeletedConter == threadCount);
                }];
            }
                break;
            case 3:
            {
                [self asyncDecodeFrames:minDuration audioFrame:_audioFrame3 videoFrame:_videoFrame3 picture:&_picture3 isPictureValid:&_pictureValid3 compeletionHandler:^(NSArray<CYPlayerFrame *> *frames) {
                    NSMutableArray * result = [[NSMutableArray alloc] initWithCapacity:20];
                    for (CYPlayerFrame * frame in frames)
                    {
                        if (frame.position >= targetPos)
                        {
                            [result addObject:frame];
                        }
                    }
                    compeletedConter++;
                    compeletion(result, compeletedConter == threadCount);
                }];
            }
                break;
            case 4:
            {
                [self asyncDecodeFrames:minDuration audioFrame:_audioFrame4 videoFrame:_videoFrame4 picture:&_picture4 isPictureValid:&_pictureValid4 compeletionHandler:^(NSArray<CYPlayerFrame *> *frames) {
                    NSMutableArray * result = [[NSMutableArray alloc] initWithCapacity:20];
                    for (CYPlayerFrame * frame in frames)
                    {
                        if (frame.position >= targetPos)
                        {
                            [result addObject:frame];
                        }
                    }
                    compeletedConter++;
                    compeletion(result, compeletedConter == threadCount);
                }];
            }
                break;
                
            default:
                break;
        }
    }
}

- (void)flush
{
    dispatch_semaphore_wait([CYGCDManager sharedManager].av_read_frame_lock, DISPATCH_TIME_FOREVER);//加锁
    if (_formatCtx) {
        avformat_flush(_formatCtx);
    }
    dispatch_semaphore_signal([CYGCDManager sharedManager].av_read_frame_lock);//放行
}

- (void) concurrentDecodeFrames:(CGFloat)minDuration compeletionHandler:(CYPlayerCompeletionDecode)compeletion
{
    if (_videoStream == -1 &&
        _audioStream == -1)
        return;
    
    __block NSMutableArray * framesArrayGroup = [[NSMutableArray alloc] initWithCapacity:10000];
    
    [self asyncDecodeFrames:minDuration audioFrame:_audioFrame videoFrame:_videoFrame picture:&_picture isPictureValid:&_pictureValid compeletionHandler:^(NSArray<CYPlayerFrame *> *frames) {
        [framesArrayGroup addObjectsFromArray:frames];
//        NSLog(@"Decode Task 1 Finish");
    }];
    
//    [self asyncDecodeFrames:minDuration audioFrame:_audioFrame videoFrame:_videoFrame picture:&_picture isPictureValid:&_pictureValid compeletionHandler:^(NSArray<CYPlayerFrame *> *frames) {
//        [framesArrayGroup addObjectsFromArray:frames];
////        NSLog(@"Decode Task 2 Finish");
//    }];
    
//    [self asyncDecodeFrames:minDuration audioFrame:_audioFrame videoFrame:_videoFrame picture:&_picture isPictureValid:&_pictureValid compeletionHandler:^(NSArray<CYPlayerFrame *> *frames) {
//        [framesArrayGroup addObjectsFromArray:frames];
//        NSLog(@"Decode Task 3 Finish");
//    }];
//
//    [self asyncDecodeFrames:minDuration audioFrame:_audioFrame videoFrame:_videoFrame picture:&_picture isPictureValid:&_pictureValid compeletionHandler:^(NSArray<CYPlayerFrame *> *frames) {
//        [framesArrayGroup addObjectsFromArray:frames];
//        NSLog(@"Decode Task 4 Finish");
//    }];
    
    
    dispatch_group_notify([CYGCDManager sharedManager].concurrent_group, [CYGCDManager sharedManager].concurrent_decode_queue, ^{
        
        compeletion(framesArrayGroup, YES);
        
//        NSLog(@"All Decode Task Finish");
    });
    
}

- (void) old_concurrentDecodeFrames:(CGFloat)minDuration compeletionHandler:(CYPlayerCompeletionDecode)compeletion
{
    if (_videoStream == -1 &&
        _audioStream == -1)
        return;
    __block NSInteger compeletedConter = 0;
    NSInteger threadCount = CYPlayerDecoderConCurrentThreadCount;
    if ([self.path hasPrefix:@"rtsp"] || [self.path hasPrefix:@"rtmp"] || [[self.path lastPathComponent] containsString:@"m3u8"])
    {
        threadCount = 4;
    }
    for (int i = 0; i < threadCount; i++)
    {
        switch (i) {
            case 0:
            {
                [self asyncDecodeFrames:minDuration audioFrame:_audioFrame videoFrame:_videoFrame picture:&_picture isPictureValid:&_pictureValid compeletionHandler:^(NSArray<CYPlayerFrame *> *frames) {
                    compeletedConter++;
                    compeletion(frames, compeletedConter == threadCount);
                }];
            }
                break;
            case 1:
            {
                [self asyncDecodeFrames:minDuration audioFrame:_audioFrame1 videoFrame:_videoFrame1 picture:&_picture1 isPictureValid:&_pictureValid1 compeletionHandler:^(NSArray<CYPlayerFrame *> *frames) {
                    compeletedConter++;
                    compeletion(frames, compeletedConter == threadCount);
                }];
            }
                break;
            case 2:
            {
                [self asyncDecodeFrames:minDuration audioFrame:_audioFrame2 videoFrame:_videoFrame2 picture:&_picture2 isPictureValid:&_pictureValid2 compeletionHandler:^(NSArray<CYPlayerFrame *> *frames) {
                    compeletedConter++;
                    compeletion(frames, compeletedConter == threadCount);
                }];
            }
                break;
            case 3:
            {
                [self asyncDecodeFrames:minDuration audioFrame:_audioFrame3 videoFrame:_videoFrame3 picture:&_picture3 isPictureValid:&_pictureValid3 compeletionHandler:^(NSArray<CYPlayerFrame *> *frames) {
                    compeletedConter++;
                    compeletion(frames, compeletedConter == threadCount);
                }];
            }
                break;
            case 4:
            {
                [self asyncDecodeFrames:minDuration audioFrame:_audioFrame4 videoFrame:_videoFrame4 picture:&_picture4 isPictureValid:&_pictureValid4 compeletionHandler:^(NSArray<CYPlayerFrame *> *frames) {
                    compeletedConter++;
                    compeletion(frames, compeletedConter == threadCount);
                }];
            }
                break;
                
            default:
                break;
        }
    }
}

- (CYPlayerFrame *)handlePreviewImagesPacket:(AVPacket *)packet videoFrame:(AVFrame *)videoFrame picture:(CYPicture *)picture isPictureValid:(BOOL *)isPictureValid
{
    __block CYPlayerFrame * result_frame = nil;
    CGFloat curr_targetPos = self.targetPosition;
    if ((*packet).stream_index ==_videoStream && self.decodeType & CYVideoDecodeTypeVideo)
    {
        int pktSize = (*packet).size;
        while (pktSize > 0 && _videoCodecCtx && curr_targetPos == self.targetPosition) {
            
            int gotframe = 0;
            dispatch_semaphore_wait([CYGCDManager sharedManager].av_send_receive_packet_lock, DISPATCH_TIME_FOREVER);//加锁
            
            int len = avcodec_send_packet(_videoCodecCtx, packet);
            packet->size -= len;
            packet->data += len;
            gotframe = !avcodec_receive_frame(_videoCodecCtx, videoFrame);
            
            dispatch_semaphore_signal([CYGCDManager sharedManager].av_send_receive_packet_lock);
            
            if (len < 0) {
                LoggerVideo(0, @"decode video error, skip packet");
                break;
            }
            
            if (gotframe) {
                CGFloat curr_position = av_frame_get_best_effort_timestamp(videoFrame) * _videoTimeBase;
                if (curr_position >= self.targetPosition)
                {
                    CYVideoFrame *frame = nil;
                    
                    if (self.validFilter)
                    {
                        if (av_buffersrc_add_frame(_buffersrc_ctx, videoFrame) < 0) {
                            printf( "Error while feeding the filtergraph\n");
                            //                    break;
                        }
                        AVFrame * pFrame_out = av_frame_alloc();
                        int ret = av_buffersink_get_frame(_buffersink_ctx, pFrame_out);
                        if (ret < 0)
                        {
                            av_frame_free(&pFrame_out);
                            continue;
                            
                        }
                        frame = [self handleVideoFrame:pFrame_out Picture:picture isPictureValid:isPictureValid];
                        av_frame_free(&pFrame_out);
                    }
                    else
                    {
                        frame = [self handleVideoFrame:videoFrame Picture:picture isPictureValid:isPictureValid];
                    }
                    
                    if (frame) {
                        
                        result_frame = frame;
                    }
                }
            }
            
            if (0 == len)
                break;
            
            pktSize -= len;
        }
        
    }
    return result_frame;
}

- (CYPlayerFrame *)handlePacket:(AVPacket *)packet audioFrame:(AVFrame *)audioFrame videoFrame:(AVFrame *)videoFrame picture:(CYPicture *)picture isPictureValid:(BOOL *)isPictureValid
{
    __block CYPlayerFrame * result_frame = nil;
    CGFloat curr_targetPos = self.targetPosition;
    if ((*packet).stream_index ==_videoStream && self.decodeType & CYVideoDecodeTypeVideo)
    {
    
        if (_useHWDecompressor && self.validVideo && _videoCodecCtx->codec_id == AV_CODEC_ID_H264)
        {
            switch (_videoCodecCtx->profile) {
                case FF_PROFILE_H264_MAIN:
                case FF_PROFILE_H264_HIGH:
                case FF_PROFILE_H264_BASELINE:
                {
                    [self.hwDecompressor decompressWithPacket:packet Completed:^(CVPixelBufferRef imageBuffer, int64_t pkt_pts, int64_t pkt_duration) {

                        if (imageBuffer == NULL) {

                            CYVideoFrame * frame;

                            CGFloat position = pkt_pts * _videoTimeBase;
                            CGFloat duration = pkt_duration * _videoTimeBase * self.rate;

                            CYVideoFrameYUV * yuvFrame = [[CYVideoFrameYUV alloc] init];
                            yuvFrame.position = position;
                            yuvFrame.duration = duration;

                            result_frame = yuvFrame;

                        }else {
                            CYVideoFrame * frame;

                            CGFloat position = pkt_pts * _videoTimeBase;
                            CGFloat duration = pkt_duration * _videoTimeBase * self.rate;


                            CVPixelBufferLockBaseAddress(imageBuffer, 0);

                            int width = (int)CVPixelBufferGetWidth(imageBuffer);
                            int height = (int)CVPixelBufferGetHeight(imageBuffer);


                            if (_videoFrameFormat == CYVideoFrameFormatYUV)
                            {
                                // yuv每 的字节数与总
                                size_t yBytes = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
                                size_t cbBytes = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1);
                                size_t crBytes = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 2);
                                //                            size_t totalByte = yBytes*height + cbBytes*height/2 + crBytes*height/2;
                                // y的数据， 度:yBytes*height
                                Byte* luma = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
                                // cb的数据， 度:cbBytes*height/2
                                Byte* chromaB = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
                                // cr的数据， 度:crBytes*height/2
                                Byte* chromaR = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 2);

                                CYVideoFrameYUV * yuvFrame = [[CYVideoFrameYUV alloc] init];

                                if (luma) yuvFrame.luma = [NSData dataWithBytes:luma length:yBytes*height];

                                if (chromaB) yuvFrame.chromaB = [NSData dataWithBytes:chromaB length:cbBytes*height/2];

                                if(chromaR) yuvFrame.chromaR = [NSData dataWithBytes:chromaR length:crBytes*height/2];

                                struct CYPixelBufferBytesPerRowOfPlane p = {yBytes, cbBytes, crBytes};
                                yuvFrame.bytesPerRowOfPlans = p;

                                frame = yuvFrame;

                                frame.width = width;
                                frame.height = height;
                                frame.position = position;
                                frame.duration = duration;
                            }
                            else
                            {

                            }

                            if (frame)
                            {
                                result_frame = frame;
                            }

                            CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
                        }
                    }];
                }
                    break;

                default:
                {
                    CVPixelBufferRef imageBuffer = [self.hwDecompressor deCompressedCMSampleBufferWithData:packet andOffset:0];


                    CYVideoFrame * frame;

                    CGFloat position = packet->pts * _videoTimeBase;
                    CGFloat duration = packet->duration * _videoTimeBase * self.rate;

                    int width = (int)CVPixelBufferGetWidth(imageBuffer);
                    int height = (int)CVPixelBufferGetHeight(imageBuffer);


                    if (_videoFrameFormat == CYVideoFrameFormatYUV)
                    {
                        // yuv每 的字节数与总
                        size_t yBytes = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
                        size_t cbBytes = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1);
                        size_t crBytes = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 2);
                        //                size_t totalByte = yBytes*height + cbBytes*height/2 + crBytes*height/2;
                        // y的数据， 度:yBytes*height
                        Byte* luma = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
                        // cb的数据， 度:cbBytes*height/2
                        Byte* chromaB = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
                        // cr的数据， 度:crBytes*height/2
                        Byte* chromaR = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 2);

                        CYVideoFrameYUV * yuvFrame = [[CYVideoFrameYUV alloc] init];
                        if (luma) yuvFrame.luma = [NSData dataWithBytes:luma length:yBytes*height];

                        if (chromaB) yuvFrame.chromaB = [NSData dataWithBytes:chromaB length:cbBytes*height/2];

                        if (chromaR) yuvFrame.chromaR = [NSData dataWithBytes:chromaR length:crBytes*height/2];

                        struct CYPixelBufferBytesPerRowOfPlane p = {yBytes, cbBytes, crBytes};
                        yuvFrame.bytesPerRowOfPlans = p;

                        frame = yuvFrame;

                        frame.width = width;
                        frame.height = height;
                        frame.position = position;
                        frame.duration = duration;
                    }
                    else
                    {

                    }

                    if (frame)
                    {
                        result_frame = frame;
                    }

                    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
                    CVPixelBufferRelease(imageBuffer);
                }
                    break;
            }
        }
        else
        {
            int pktSize = (*packet).size;
            while (pktSize > 0 && _videoCodecCtx && curr_targetPos == self.targetPosition) {
                
                int gotframe = 0;
                dispatch_semaphore_wait([CYGCDManager sharedManager].av_send_receive_packet_lock, DISPATCH_TIME_FOREVER);//加锁
                CFAbsoluteTime startTime =CFAbsoluteTimeGetCurrent();
                int len = avcodec_send_packet(_videoCodecCtx, packet);
                packet->size -= len;
                packet->data += len;
                gotframe = !avcodec_receive_frame(_videoCodecCtx, videoFrame);
                CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
#ifdef DEBUG
                NSLog(@"avcodec_send_receive_packet in %.2f ms", linkTime * 1000.0);
#endif
                dispatch_semaphore_signal([CYGCDManager sharedManager].av_send_receive_packet_lock);
                
                if (len < 0) {
                    LoggerVideo(0, @"decode video error, skip packet");
                    break;
                }
                
                if (gotframe) {
                    CGFloat curr_position = av_frame_get_best_effort_timestamp(videoFrame) * _videoTimeBase;
                    if (curr_position >= self.targetPosition)
                    {
                        CYVideoFrame *frame = nil;
                        
                        if (self.validFilter)
                        {
                            if (av_buffersrc_add_frame(_buffersrc_ctx, videoFrame) < 0) {
                                printf( "Error while feeding the filtergraph\n");
                                //                    break;
                            }
                            AVFrame * pFrame_out = av_frame_alloc();
                            int ret = av_buffersink_get_frame(_buffersink_ctx, pFrame_out);
                            if (ret < 0)
                            {
                                av_frame_free(&pFrame_out);
                                continue;
                                
                            }
                            frame = [self handleVideoFrame:pFrame_out Picture:picture isPictureValid:isPictureValid];
                            av_frame_free(&pFrame_out);
                        }
                        else
                        {
                            frame = [self handleVideoFrame:videoFrame Picture:picture isPictureValid:isPictureValid];
                        }
                        
                        if (frame) {
                            
                            result_frame = frame;
                        }
                    }
                }
                
                if (0 == len)
                    break;
                
                pktSize -= len;
            }
        }
    }
    else if ((*packet).stream_index == _audioStream && self.decodeType & CYVideoDecodeTypeAudio)
    {
        
        int pktSize = (*packet).size;
        
        while (pktSize > 0 && _audioCodecCtx && curr_targetPos == self.targetPosition) {
            
            int gotframe = 0;
            
            dispatch_semaphore_wait([CYGCDManager sharedManager].av_send_receive_packet_lock, DISPATCH_TIME_FOREVER);//加锁
            int len = avcodec_send_packet(_audioCodecCtx, packet);
            packet->size -= len;
            packet->data += len;
            gotframe = !avcodec_receive_frame(_audioCodecCtx, audioFrame);
            dispatch_semaphore_signal([CYGCDManager sharedManager].av_send_receive_packet_lock);
            
            if (len < 0) {
                LoggerAudio(0, @"decode audio error, skip packet");
                break;
            }
            
            if (gotframe) {
                CGFloat curr_position = av_frame_get_best_effort_timestamp(audioFrame) * _audioTimeBase;
                if (curr_position >= self.targetPosition)
                {
                    @synchronized (self)
                    {
//                        NSLog(@"%@ in", [NSThread currentThread]);
                        CYAudioFrame * frame = [self handleAudioFrame:audioFrame];
                        if (frame) {
                            
                            result_frame = frame;
                        }
                        
//                        NSLog(@"%@ out", [NSThread currentThread]);
                    }
                }
            }
            
            if (0 == len)
                break;
            
            pktSize -= len;
        }
        
    }
    else if ((*packet).stream_index == _artworkStream)
    {
        
        if ((*packet).size) {
            
            CYArtworkFrame *frame = [[CYArtworkFrame alloc] init];
            frame.picture = [NSData dataWithBytes:(*packet).data length:(*packet).size];
            if (frame)
            {
                result_frame = frame;
            }
        }
        
    }
    else if ((*packet).stream_index == _subtitleStream)
    {
        
        int pktSize = (*packet).size;
        
        while (pktSize > 0 && _subtitleCodecCtx && curr_targetPos == self.targetPosition) {
            
            AVSubtitle subtitle;
            int gotsubtitle = 0;
            int len = avcodec_decode_subtitle2(_subtitleCodecCtx,
                                               &subtitle,
                                               &gotsubtitle,
                                               packet);
            
            if (len < 0) {
                LoggerStream(0, @"decode subtitle error, skip packet");
                break;
            }
            
            if (gotsubtitle) {
                CGFloat curr_position = subtitle.pts / AV_TIME_BASE + subtitle.start_display_time;
                if (curr_position >= self.targetPosition)
                {
                    CYSubtitleFrame *frame = [self handleSubtitle: &subtitle];
                    if (frame) {
                        result_frame = frame;
                    }
                }
            }
            
            if (&subtitle != NULL)
            {
                avsubtitle_free(&subtitle);
            }
            
            if (0 == len)
                break;
            
            pktSize -= len;
        }
    }

    return result_frame;
}

+ (NSString *)getImageCachePath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = CY_CachesPath(@"ffmpeg_cache");
    
    BOOL isDir = FALSE;
    BOOL isDirExist = [fileManager fileExistsAtPath:filePath isDirectory:&isDir];
    if(!(isDirExist && isDir)){
        BOOL bCreateDir = [fileManager createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:nil];
        if(!bCreateDir){
            NSLog(@"Create ffmpeg_cache Directory Failed.");
            return nil;
        }else {
            return filePath;
        }
    }else{
        return filePath;
    }
}

+ (NSString *)getImagePathWithPath:(NSString *)path
{
    NSString * imagePath = [[NSUserDefaults standardUserDefaults] objectForKey:path];
    if (!imagePath || imagePath.length <= 0) {
        return nil;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:imagePath]) {
        return nil;
    }
    return imagePath;
}

+ (void)generatedPreviewImagesWithPath:(NSString *)path
                                  time:(NSTimeInterval)time
                     completionHandler:(void (^)(NSMutableArray * frames, NSError * error))handler
{
    @synchronized (self)
    {
        NSString * imagePath = [self getImagePathWithPath:path];
        if (imagePath.length > 0){
            handler([@[imagePath] mutableCopy], nil);
        } else {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                NSString * intervalStr = [NSString stringWithFormat:@"%f", time];
                char * timeInterval = (char *)[intervalStr UTF8String];
                char *movie = (char *)[path UTF8String];
                NSString * cyTmpPath = [self getImageCachePath];
                NSString * outPath = [cyTmpPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_",[path lastPathComponent]]];
                outPath = [outPath stringByAppendingFormat:@"%f.jpg",time];
                char *outPic = (char *)[outPath UTF8String];
                //ffmpeg -i Downloads.mp4 -r 1 -ss 00:20 -vframes 1 %3d.jpg
                char* a[] = {
                    "ffmpeg",
                    "-ss",
                    timeInterval,
                    "-i",
                    movie,
                    "-f",
                    "image2",
                    "-r",
                    "25",
                    "-vframes",
                    "1",
                    outPic
                };
                
                dispatch_semaphore_wait([CYGCDManager sharedManager].av_read_frame_lock, DISPATCH_TIME_FOREVER);//加锁
                int result = ffmpeg_main(sizeof(a)/sizeof(*a), a);
                dispatch_semaphore_signal([CYGCDManager sharedManager].av_read_frame_lock);
                
                NSError * error = nil;
                NSMutableArray * models = [[NSMutableArray alloc] initWithCapacity:1];
                if (result != 0) {
                    error = [NSError errorWithDomain:cyplayerErrorDomain code:result userInfo:nil];
                }else{
                    [models addObject:outPath];
                    [[NSUserDefaults standardUserDefaults] setObject:outPath forKey:path];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (handler) {
                        handler(models, error);
                    }
                });
            });
        }
    }
    
}

# pragma mark - NotificationCenter

- (void)audioRouteChangeListenerCallback:(NSNotification*)notification
{
    dispatch_semaphore_wait([CYGCDManager sharedManager].swr_context_lock, DISPATCH_TIME_FOREVER);
#ifdef USE_OPENAL
    CYPCMAudioManager * audioManager = [CYPCMAudioManager audioManager];
#endif
    
#ifdef USE_AUDIOTOOL
    id<CYAudioManager> audioManager = [CYAudioManager audioManager];
#endif
    int64_t audioChannel = av_get_default_channel_layout((int)(audioManager.avcodecContextNumOutputChannels));
    int64_t swrcontext_channel;
    av_opt_get_int(_swrContext, "out_channel_layout", 0, &swrcontext_channel);
    if (audioChannel != swrcontext_channel)
    {
        BOOL result = audio_swr_resampling_audio_init(&_swrContext, _audioCodecCtx, _rate);
        if (!result)
        {
            
        }
    }
    dispatch_semaphore_signal([CYGCDManager sharedManager].swr_context_lock);
}

# pragma mark - Last Version API
- (NSArray *) decodeTargetFrames: (CGFloat) minDuration :(CGFloat)targetPos
{
    if (_videoStream == -1 &&
        _audioStream == -1)
        return nil;
    
    NSMutableArray *result = [NSMutableArray array];
    
    AVPacket packet;
    
    CGFloat decodedDuration = 0;
    
    BOOL finished = NO;
    
    while (!finished && _formatCtx) {
        
        if (av_read_frame(_formatCtx, &packet) < 0) {
            _isEOF = YES;
            av_packet_unref(&packet);
            break;
        }
        
        if (packet.stream_index == _audioStream && self.decodeType & CYVideoDecodeTypeAudio) {
            
            int pktSize = packet.size;
            
            while (pktSize > 0 && _audioCodecCtx) {
                
                int gotframe = 0;
                int len = avcodec_send_packet(_audioCodecCtx, &packet);
                packet.size -= len;
                packet.data += len;
                gotframe = !avcodec_receive_frame(_audioCodecCtx, _audioFrame);
                
                if (len < 0) {
                    LoggerAudio(0, @"decode audio error, skip packet");
                    break;
                }
                
                if (gotframe) {
                    CGFloat curr_position = av_frame_get_best_effort_timestamp(_audioFrame) * _audioTimeBase;
                    if (curr_position >= targetPos)
                    {
                        CYAudioFrame * frame = [self handleAudioFrame:_audioFrame];
                        if (frame) {
                            
                            [result addObject:frame];
                            
                            if (_videoStream == -1) {
                                
                                _position = frame.position;
                                decodedDuration += frame.duration;
                                if (decodedDuration > minDuration)
                                    finished = YES;
                            }
                        }
                    }
                }
                
                if (0 == len)
                    break;
                
                pktSize -= len;
            }
            
        } else if (packet.stream_index ==_videoStream && self.decodeType & CYVideoDecodeTypeVideo) {
            
            int pktSize = packet.size;
            
            while (pktSize > 0 && _videoCodecCtx) {
                
                int gotframe = 0;
                //                int len = avcodec_decode_video2(_videoCodecCtx,
                //                                                _videoFrame,
                //                                                &gotframe,
                //                                                &packet);
                int len = avcodec_send_packet(_videoCodecCtx, &packet);
                packet.size -= len;
                packet.data += len;
                gotframe = !avcodec_receive_frame(_videoCodecCtx, _videoFrame);
                
                if (len < 0) {
                    LoggerVideo(0, @"decode video error, skip packet");
                    break;
                }
                
                if (gotframe) {
                    CGFloat curr_position = av_frame_get_best_effort_timestamp(_videoFrame) * _videoTimeBase;
                    if (curr_position >= targetPos)
                    {
                        CYVideoFrame *frame = [self handleVideoFrame:_videoFrame Picture:&_picture isPictureValid:&_pictureValid];
                        if (frame) {
                            
                            [result addObject:frame];
                            
                            _position = frame.position;
                            decodedDuration += frame.duration;
                            if (decodedDuration > minDuration)
                                finished = YES;
                        }
                    }
                }
                
                if (0 == len)
                    break;
                
                pktSize -= len;
            }
            
        } else if (packet.stream_index == _artworkStream) {
            
            if (packet.size) {
                
                CYArtworkFrame *frame = [[CYArtworkFrame alloc] init];
                frame.picture = [NSData dataWithBytes:packet.data length:packet.size];
                [result addObject:frame];
            }
            
        } else if (packet.stream_index == _subtitleStream) {
            
            int pktSize = packet.size;
            
            while (pktSize > 0) {
                
                AVSubtitle subtitle;
                int gotsubtitle = 0;
                int len = avcodec_decode_subtitle2(_subtitleCodecCtx,
                                                   &subtitle,
                                                   &gotsubtitle,
                                                   &packet);
                
                if (len < 0) {
                    LoggerStream(0, @"decode subtitle error, skip packet");
                    break;
                }
                if (gotsubtitle) {
                    CGFloat curr_position = subtitle.pts / AV_TIME_BASE + subtitle.start_display_time;
                    if (curr_position >= targetPos)
                    {
                        CYSubtitleFrame *frame = [self handleSubtitle: &subtitle];
                        if (frame) {
                            [result addObject:frame];
                        }
                    }
                }
                avsubtitle_free(&subtitle);
                
                if (0 == len)
                    break;
                
                pktSize -= len;
            }
        }
        av_packet_unref(&packet);
    }
    av_packet_free(&packet);
    
    return result;
}


- (NSArray *) old_decodeFrames: (CGFloat) minDuration
{
    if (_videoStream == -1 &&
        _audioStream == -1)
        return nil;
    
    NSMutableArray *result = [NSMutableArray array];
    
    AVPacket packet;
    
    CGFloat decodedDuration = 0;
    
    BOOL finished = NO;
    
    while (!finished && _formatCtx) {
        CFAbsoluteTime startTime =CFAbsoluteTimeGetCurrent();
        if (av_read_frame(_formatCtx, &packet) < 0) {
            _isEOF = YES;
            av_packet_unref(&packet);
            break;
        }
        CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
        //NSLog(@"Linked av_read_frame in %f ms", linkTime *1000.0);
        
        if (packet.stream_index ==_videoStream && self.decodeType & CYVideoDecodeTypeVideo) {
            
            int pktSize = packet.size;
            
            while (pktSize > 0 && _videoCodecCtx) {
                
                int gotframe = 0;
                int len = avcodec_send_packet(_videoCodecCtx, &packet);
                packet.size -= len;
                packet.data += len;
                gotframe = !avcodec_receive_frame(_videoCodecCtx, _videoFrame);
                
                if (len < 0) {
                    LoggerVideo(0, @"decode video error, skip packet");
                    break;
                }
                
                if (gotframe) {
                    
                    CYVideoFrame *frame = [self handleVideoFrame:_videoFrame Picture:&_picture isPictureValid:&_pictureValid];
                    if (frame) {
                        
                        [result addObject:frame];
                        
                        if (frame.position >= _position)
                        {
                            _position = _position + frame.duration;
                            decodedDuration += frame.duration;
                        }
                        
                        if (decodedDuration > minDuration)
                            finished = YES;
                    }
                }
                
                if (0 == len)
                    break;
                
                pktSize -= len;
            }
            
        } else if (packet.stream_index == _audioStream && self.decodeType & CYVideoDecodeTypeAudio) {
            
            int pktSize = packet.size;
            
            while (pktSize > 0 && _audioCodecCtx) {
                
                int gotframe = 0;
                
                int len = avcodec_send_packet(_audioCodecCtx, &packet);
                packet.size -= len;
                packet.data += len;
                gotframe = !avcodec_receive_frame(_audioCodecCtx, _audioFrame);
                
                if (len < 0) {
                    LoggerAudio(0, @"decode audio error, skip packet");
                    break;
                }
                
                if (gotframe) {
                    
                    CYAudioFrame * frame = [self handleAudioFrame:_audioFrame];
                    if (frame) {
                        
                        [result addObject:frame];
                        
                        if (_videoStream == -1) {
                            
                            //                            _position = frame.position;
                            //                            decodedDuration += frame.duration;
                            if (frame.position >= _position)
                            {
                                _position = _position + frame.duration;
                                decodedDuration += frame.duration;
                            }
                            if (decodedDuration > minDuration)
                                finished = YES;
                        }
                    }
                }
                
                if (0 == len)
                    break;
                
                pktSize -= len;
            }
            
        } else if (packet.stream_index == _artworkStream) {
            
            if (packet.size) {
                
                CYArtworkFrame *frame = [[CYArtworkFrame alloc] init];
                frame.picture = [NSData dataWithBytes:packet.data length:packet.size];
                [result addObject:frame];
            }
            
        } else if (packet.stream_index == _subtitleStream) {
            
            int pktSize = packet.size;
            
            while (pktSize > 0) {
                
                AVSubtitle subtitle;
                int gotsubtitle = 0;
                int len = avcodec_decode_subtitle2(_subtitleCodecCtx,
                                                   &subtitle,
                                                   &gotsubtitle,
                                                   &packet);
                
                if (len < 0) {
                    LoggerStream(0, @"decode subtitle error, skip packet");
                    break;
                }
                
                if (gotsubtitle) {
                    
                    CYSubtitleFrame *frame = [self handleSubtitle: &subtitle];
                    if (frame) {
                        [result addObject:frame];
                    }
                    avsubtitle_free(&subtitle);
                }
                
                if (0 == len)
                    break;
                
                pktSize -= len;
            }
        }
        av_packet_unref(&packet);
        //        av_free_packet(&packet);
    }
    av_packet_unref(&packet);
    
    return result;
}

- (NSArray *) decodePreviewImagesFrames: (CGFloat) minDuration
{
    if (_videoStream == -1 &&
        _audioStream == -1)
        return nil;
    
    NSMutableArray *result = [NSMutableArray array];
    
    AVPacket * packet = av_packet_alloc();
    
    CGFloat decodedDuration = 0;
    
    BOOL finished = NO;
    
    CFAbsoluteTime startTime =CFAbsoluteTimeGetCurrent();
    
    while (!finished && _formatCtx) {
//        CFAbsoluteTime startTime =CFAbsoluteTimeGetCurrent();
        if ([self.path hasPrefix:@"smb://"]) {
            dispatch_semaphore_wait([CYGCDManager sharedManager].av_read_frame_lock, DISPATCH_TIME_FOREVER);//加锁
            if (av_read_frame(_formatCtx, packet) < 0) {
                _isEOF = YES;
                av_packet_unref(packet);
                dispatch_semaphore_signal([CYGCDManager sharedManager].av_read_frame_lock);//放行
                break;
            }
            dispatch_semaphore_signal([CYGCDManager sharedManager].av_read_frame_lock);//放行
        }else {
            dispatch_semaphore_wait([CYGCDManager sharedManager].decode_preview_images_frames_av_read_frame_lock, DISPATCH_TIME_FOREVER);//加锁
            if (av_read_frame(_formatCtx, packet) < 0) {
                _isEOF = YES;
                av_packet_unref(packet);
                dispatch_semaphore_signal([CYGCDManager sharedManager].decode_preview_images_frames_av_read_frame_lock);//放行
                break;
            }
            dispatch_semaphore_signal([CYGCDManager sharedManager].decode_preview_images_frames_av_read_frame_lock);//放行
        }
        
//        CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
        //NSLog(@"Linked av_read_frame in %f ms", linkTime *1000.0);
        
        CYPlayerFrame * frame = [self handlePreviewImagesPacket:packet videoFrame:_videoFrame picture:&_picture isPictureValid:&_pictureValid];
        if (frame)
        {
            [result addObject:frame];
            if (_videoStream == -1) {
                if (frame.position >= _position)
                {
                    _position = _position + frame.duration;
                    decodedDuration += frame.duration;
                }
                if (decodedDuration > minDuration)
                    finished = YES;
            }
            else
            {
                if (frame.type == CYPlayerFrameTypeVideo)
                {
                    if (frame.position >= _position)
                    {
                        _position = _position + frame.duration;
                        decodedDuration += frame.duration;
                    }
                }
                
                if (decodedDuration > minDuration)
                    finished = YES;
            }
        }
        
        
        av_packet_unref(packet);
    }
    av_packet_unref(packet);
    av_packet_free(&packet);
    CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
    #ifdef DEBUG
//                NSLog(@"decodePreviewImagesFrames in %.2f ms", linkTime * 1000.0);
    #endif
    return result;
}

- (NSArray *) decodeFrames: (CGFloat) minDuration
{
    if (_videoStream == -1 &&
        _audioStream == -1)
        return nil;
    
    NSMutableArray *result = [NSMutableArray array];
    
    AVPacket * packet = av_packet_alloc();
    
    CGFloat decodedDuration = 0;
    
    BOOL finished = NO;
    
    while (!finished && _formatCtx) {
        CFAbsoluteTime startTime =CFAbsoluteTimeGetCurrent();
        dispatch_semaphore_wait([CYGCDManager sharedManager].av_read_frame_lock, DISPATCH_TIME_FOREVER);//加锁
        if (av_read_frame(_formatCtx, packet) < 0) {
            _isEOF = YES;
            av_packet_unref(packet);
            dispatch_semaphore_signal([CYGCDManager sharedManager].av_read_frame_lock);//放行
            break;
        }
        dispatch_semaphore_signal([CYGCDManager sharedManager].av_read_frame_lock);//放行
        CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
        //NSLog(@"Linked av_read_frame in %f ms", linkTime *1000.0);
        
        CYPlayerFrame * frame = [self handlePacket:packet audioFrame:_audioFrame videoFrame:_videoFrame picture:&_picture isPictureValid:&_pictureValid];
        if (frame)
        {
            [result addObject:frame];
            if (_videoStream == -1) {
                if (frame.position >= _position)
                {
                    _position = _position + frame.duration;
                    decodedDuration += frame.duration;
                }
                if (decodedDuration > minDuration)
                    finished = YES;
            }
            else
            {
                if (frame.type == CYPlayerFrameTypeVideo)
                {
                    if (frame.position >= _position)
                    {
                        _position = _position + frame.duration;
                        decodedDuration += frame.duration;
                    }
                }
                
                if (decodedDuration > minDuration)
                    finished = YES;
            }
        }
        
        
        av_packet_unref(packet);
    }
    av_packet_unref(packet);
    av_packet_free(&packet);

    return result;
}


@end

//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////

static int av_read_frame_time_out = 0;

static CFAbsoluteTime _av_read_frame_time;

static int interrupt_callback(void *ctx)
{
    if (!ctx)
        return 0;
    __unsafe_unretained CYPlayerDecoder *p = (__bridge CYPlayerDecoder *)ctx;
    const BOOL r = [p interruptDecoder];
    if (r) LoggerStream(1, @"DEBUG: INTERRUPT_CALLBACK!");
//    av_read_frame_time_out++;
//    if (av_read_frame_time_out > 40) {
//        av_read_frame_time_out = 0;
//        return 1;
//    }
//    CFAbsoluteTime av_read_frame_time = CFAbsoluteTimeGetCurrent();
//    if (!_av_read_frame_time) {
//        _av_read_frame_time = CFAbsoluteTimeGetCurrent();
//    }
//    else{
//        CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - _av_read_frame_time);
//        NSLog(@"_av_read_frame_time  in %.2f ms", linkTime *1000.0);
//        _av_read_frame_time = CFAbsoluteTimeGetCurrent();
//    }
    return r;

}


#ifdef SMBCLIENT_H_INCLUDED
static void my_smbc_get_auth_data_fn (const char *srv,
                                      const char *shr,
                                      char *wg, int wglen,
                                      char *un, int unlen,
                                      char *pw, int pwlen)
{
    
}


static CFAbsoluteTime _smb_last_link_time;//用于samba的session超时计算

static int my_libsmbc_connect(URLContext *h)
{
    LIBSMBContext *libsmbc = h->priv_data;
//  //这里替换掉原有的ffmpeg写法,是因为每次open_input造成会调用这个connect,然后smbc_new_context造成原有context失效,崩溃
//    libsmbc->ctx = smbc_new_context();
//    if (!libsmbc->ctx) {
//        int ret = AVERROR(errno);
//        av_log(h, AV_LOG_ERROR, "Cannot create context: %s.\n", strerror(errno));
//        return ret;
//    }
//    if (!smbc_init_context(libsmbc->ctx)) {
//        int ret = AVERROR(errno);
//        av_log(h, AV_LOG_ERROR, "Cannot initialize context: %s.\n", strerror(errno));
//        return ret;
//    }
    libsmbc->ctx = smbc_set_context(NULL);
    if (libsmbc->ctx == NULL) {
        if (smbc_init(my_smbc_get_auth_data_fn, 0) < 0) {
            int ret = AVERROR(errno);
            av_log(h, AV_LOG_ERROR, "Cannot initialize context: %s.\n", strerror(errno));
            return ret;
        }
        libsmbc->ctx = smbc_set_context(NULL);
    }
    
    //#ifdef DEBUG
    if (!_smb_last_link_time) {
        _smb_last_link_time = CFAbsoluteTimeGetCurrent();
    }
    else{
        CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - _smb_last_link_time);
#ifdef DEBUG
        NSLog(@"_smb_last_link_time: %.2f", linkTime);
#endif
        
        if (linkTime > 120) {
            
        }
        
        _smb_last_link_time = CFAbsoluteTimeGetCurrent();
    }
    
    

    smbc_setOptionUserData(libsmbc->ctx, h);
    smbc_setTimeout(libsmbc->ctx, 5000);
//    smbc_setFunctionAuthDataWithContext(libsmbc->ctx, libsmbc_get_auth_data);

    if (libsmbc->timeout != -1)
        smbc_setTimeout(libsmbc->ctx, libsmbc->timeout);
    if (libsmbc->workgroup)
        smbc_setWorkgroup(libsmbc->ctx, libsmbc->workgroup);

    if (smbc_init(my_smbc_get_auth_data_fn, 0) < 0) {
        int ret = AVERROR(errno);
        av_log(h, AV_LOG_ERROR, "Initialization failed: %s\n", strerror(errno));
        return ret;
    }
    return 0;
}

static int my_libsmbc_close(URLContext *h)
{
    LIBSMBContext *libsmbc = h->priv_data;
    if (libsmbc->fd >= 0) {
        smbc_close(libsmbc->fd);
        libsmbc->fd = -1;
    }
    if (libsmbc->ctx) {
//        smbc_free_context(libsmbc->ctx, 1);
//        libsmbc->ctx = NULL;
    }
    return 0;
}

static int my_libsmbc_close2(URLContext *h)
{
    LIBSMBContext *libsmbc = h->priv_data;
    if (libsmbc->fd >= 0) {
        smbc_close(libsmbc->fd);
        libsmbc->fd = -1;
    }
    if (libsmbc->ctx) {
        if (!smbc_free_context(libsmbc->ctx, 1)){
            libsmbc->ctx = (SMBCCTX *)smbc_new_context();
            smbc_init_context(libsmbc->ctx);
            smbc_set_context(libsmbc->ctx);
        }
    }
    return 0;
}

static int my_libsmbc_open( URLContext *h, const char *url, int flags)
{
    LIBSMBContext *libsmbc = h->priv_data;
    int access, ret;
    struct stat st;
    
    libsmbc->fd = -1;
    libsmbc->filesize = -1;
    
    if ((ret = my_libsmbc_connect(h)) < 0)
        goto fail;
    
    if ((flags & AVIO_FLAG_WRITE) && (flags & AVIO_FLAG_READ)) {
        access = O_CREAT | O_RDWR;
        if (libsmbc->trunc)
            access |= O_TRUNC;
    } else if (flags & AVIO_FLAG_WRITE) {
        access = O_CREAT | O_WRONLY;
        if (libsmbc->trunc)
            access |= O_TRUNC;
    } else
        access = O_RDONLY;
    
    /* 0666 = -rw-rw-rw- = read+write for everyone, minus umask */
    if ((libsmbc->fd = smbc_open(url, access, 0666)) < 0) {
        ret = AVERROR(errno);
        av_log(h, AV_LOG_ERROR, "File open failed: %s\n", strerror(errno));
        if (errno == ETIMEDOUT) {
            goto fail2;
        }
        goto fail;
    }
    
    if (smbc_fstat(libsmbc->fd, &st) < 0)
        av_log(h, AV_LOG_WARNING, "Cannot stat file: %s\n", strerror(errno));
    else
        libsmbc->filesize = st.st_size;
    
    return 0;
fail:
    my_libsmbc_close(h);
    return ret;
    
fail2:
    my_libsmbc_close2(h);
    return ret;
}

#endif
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////

@implementation CYPlayerSubtitleASSParser

+ (NSArray *) parseEvents: (NSString *) events
{
    NSRange r = [events rangeOfString:@"[Events]"];
    if (r.location != NSNotFound) {
        
        NSUInteger pos = r.location + r.length;
        
        r = [events rangeOfString:@"Format:"
                          options:0
                            range:NSMakeRange(pos, events.length - pos)];
        
        if (r.location != NSNotFound) {
            
            pos = r.location + r.length;
            r = [events rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]
                                        options:0
                                          range:NSMakeRange(pos, events.length - pos)];
            
            if (r.location != NSNotFound) {
                
                NSString *format = [events substringWithRange:NSMakeRange(pos, r.location - pos)];
                NSArray *fields = [format componentsSeparatedByString:@","];
                if (fields.count > 0) {
                    
                    NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet];
                    NSMutableArray *ma = [NSMutableArray array];
                    for (NSString *s in fields) {
                        [ma addObject:[s stringByTrimmingCharactersInSet:ws]];
                    }
                    return ma;
                }
            }
        }
    }
    
    return nil;
}

+ (NSArray *) parseDialogue: (NSString *) dialogue
                  numFields: (NSUInteger) numFields
{
    if ([dialogue hasPrefix:@"Dialogue:"]) {
        
        NSMutableArray *ma = [NSMutableArray array];
        
        NSRange r = {@"Dialogue:".length, 0};
        NSUInteger n = 0;
        
        while (r.location != NSNotFound && n++ < numFields) {
            
            const NSUInteger pos = r.location + r.length;
            
            r = [dialogue rangeOfString:@","
                                options:0
                                  range:NSMakeRange(pos, dialogue.length - pos)];
            
            const NSUInteger len = r.location == NSNotFound ? dialogue.length - pos : r.location - pos;
            NSString *p = [dialogue substringWithRange:NSMakeRange(pos, len)];
            p = [p stringByReplacingOccurrencesOfString:@"\\N" withString:@"\n"];
            [ma addObject: p];
        }
        
        return ma;
    }
    
    return nil;
}

+ (NSString *) removeCommandsFromEventText: (NSString *) text
{
    NSMutableString *ms = [NSMutableString string];
    
    NSScanner *scanner = [NSScanner scannerWithString:text];
    while (!scanner.isAtEnd) {
        
        NSString *s;
        if ([scanner scanUpToString:@"{\\" intoString:&s]) {
            
            [ms appendString:s];
        }
        
        if (!([scanner scanString:@"{\\" intoString:nil] &&
              [scanner scanUpToString:@"}" intoString:nil] &&
              [scanner scanString:@"}" intoString:nil])) {
            
            break;
        }
    }
    
    return ms;
}


@end

static void FFLog(void* context, int level, const char* format, va_list args) {
    @autoreleasepool {
        //Trim time at the beginning and new line at the end
        NSString* message = [[NSString alloc] initWithFormat: [NSString stringWithUTF8String: format] arguments: args];
        switch (level) {
            case 0:
            case 1:
                LoggerStream(0, @"%@", [message stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]]);
                break;
            case 2:
                LoggerStream(1, @"%@", [message stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]]);
                break;
            case 3:
            case 4:
                LoggerStream(2, @"%@", [message stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]]);
                break;
            default:
                LoggerStream(3, @"%@", [message stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]]);
                break;
        }
    }
}

