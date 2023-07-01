//
//  CYHardwareDecompressVideo.h
//  CYPlayer
//
//  Created by 黄威 on 2018/9/20.
//
#import <CYFFmpeg/CYFFmpeg.h>
#import <VideoToolbox/VideoToolbox.h>
#import <Foundation/Foundation.h>

typedef struct _NALUnit{
    unsigned int type;
    unsigned int size;
    unsigned char *data;
    int64_t pts;
    int64_t dts;
    int64_t duration;
}NALUnit;

typedef enum{
    NALUTypeBPFrame = 0x01,
    NALUTypeIFrame = 0x05,
    NALUTypeSPS = 0x07,
    NALUTypePPS = 0x08
}NALUType;

typedef void(^CYHwDecompressCompleted)(CVPixelBufferRef imageBuffer,
                                       int64_t pkt_pts,
                                       int64_t pkt_duration);

@interface CYHardwareDecompressVideo : NSObject

@property (nonatomic, readonly, assign) BOOL canHWDecompressing;

- (id)init;
- (BOOL)takePicture:(NSString *)fileName;
- (CVPixelBufferRef)deCompressedCMSampleBufferWithData:(AVPacket*)packet andOffset:(int)offset;


# pragma mark - Test API
- (id)initWithCodecCtx:(AVCodecContext *)codecCtx;

/**
 AVPacket中没有分隔编码0x00000001的情况下使用

 @param packet <#packet description#>
 @param completed <#completed description#>
 */
- (void)decompressWithPacket:(AVPacket *)packet Completed:(CYHwDecompressCompleted)completed;
@end

