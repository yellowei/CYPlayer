//
//  CYHardwareDecompressVideo.m
//  CYPlayer
//
//  Created by 黄威 on 2018/9/20.
//

#import <UIKit/UIKit.h>
#import "CYHardwareDecompressVideo.h"

@interface CYHardwareDecompressVideo ()
@property (nonatomic, readwrite, assign) BOOL canHWDecompressing;
@end

@implementation CYHardwareDecompressVideo{
    uint8_t *_sps;
    uint8_t *_pps;
    
    BOOL _isTakePicture;
    BOOL _isSaveTakePictureImage;
    NSString *_saveTakePicturePath;
    
    unsigned int _spsSize;
    unsigned int _ppsSize;
    
    int64_t mCurrentVideoSeconds;
    VTDecompressionSessionRef _decompressionSession;
    CMVideoFormatDescriptionRef _decompressionFormatDesc;
}

-(id)init
{
    if(self = [super init]){
        _isTakePicture = false;
    }
    
    return self;
}



-(BOOL)takePicture:(NSString *)fileName
{
    _isTakePicture = true;
    _isSaveTakePictureImage = false;
    _saveTakePicturePath = fileName;
    
    while(_isSaveTakePictureImage == false){
        //Just waiting "_isSaveTakePictureImage" become true.
    }
    
    _isTakePicture = false;
    return true;;
}

/*
 在使用FFMPEG的类库进行编程的过程中，可以直接输出解复用之后的的视频数据码流。只需要在每次调用av_read_frame()之后将得到的视频的AVPacket存为本地文件即可。
 
 经试验，在分离MPEG2码流的时候，直接存储AVPacket即可。
 
 在分离H.264码流的时候，直接存储AVPacket后的文件可能是不能播放的。
 
 如果视音频复用格式是TS（MPEG2 Transport Stream），直接存储后的文件是可以播放的。
 
 复用格式是FLV，MP4则不行。
 
 经过长时间资料搜索发现，FLV，MP4这些属于“特殊容器”，需要经过以下处理才能得到可播放的H.264码流：
 
 1.第一次存储AVPacket之前需要在前面加上H.264的SPS和PPS。这些信息存储在AVCodecContext的extradata里面。
 
 并且需要使用FFMPEG中的名为"h264_mp4toannexb"的bitstream filter 进行处理。
 
 然后将处理后的extradata存入文件
 
 2.通过查看FFMPEG源代码我们发现，AVPacket中的数据起始处没有分隔符(0x00000001), 也不是0x65、0x67、0x68、0x41等字节，所以可以AVPacket肯定这不是标准的nalu。其实，AVPacket前4个字表示的是nalu的长度，从第5个字节开始才是nalu的数据。所以直接将AVPacket前4个字节替换为0x00000001即可得到标准的nalu数据。
 */
- (CVPixelBufferRef)deCompressedCMSampleBufferWithData:(AVPacket*)packet andOffset:(int)offset
{
    NALUnit nalUnit;
    CVPixelBufferRef pixelBufferRef = NULL;
    char *data = (char*)packet->data;
    int dataLen = packet->size;
    
    if(data == NULL || dataLen == 0){
        return NULL;
    }
    //H264 start code
    if ((data[0] != 0x00 ||
         data[1] != 0x00 ||
         data[2] != 0x00 ||
         data[3] != 0x01))
    {
//        uint8_t * data_tmp = (uint8_t*)malloc(sizeof(uint8_t)*(dataLen + 4));
//        data_tmp[0] = 0x00;
//        data_tmp[1] = 0x00;
//        data_tmp[2] = 0x00;
//        data_tmp[3] = 0x01;
//        memcpy((data_tmp + 4), data+4, dataLen-4);
//        data = (char*)data_tmp;
//        fill_code_length = 4;
//        dataLen += 4;
        data[0] = 0x00;
        data[1] = 0x00;
        data[2] = 0x00;
        data[3] = 0x01;
    }

    while([self nalunitWithData:data andDataLen:dataLen andOffset:offset toNALUnit:&nalUnit])
    {
        if(nalUnit.data == NULL || nalUnit.size == 0){
            return NULL;
        }
        
        pixelBufferRef = NULL;
        [self infalteStartCodeWithNalunitData:&nalUnit];
        NSLog(@"NALUint Type: %d.", nalUnit.type);
        
        switch (nalUnit.type) {
            case NALUTypeIFrame://IFrame
                if(_sps && _pps)
                {
                    if([self initH264Decoder]){
                        pixelBufferRef = [self decompressWithAVPacket:packet];
                        NSLog(@"NALUint I Frame size:%d", nalUnit.size);
                        
                        free(_sps);
                        free(_pps);
                        _pps = NULL;
                        _sps = NULL;
                        return pixelBufferRef;
                    }
                }
                break;
            case NALUTypeSPS://SPS
                _spsSize = nalUnit.size - 4;
                if(_spsSize <= 0){
                    return NULL;
                }
                
                _sps = (uint8_t*)malloc(_spsSize);
                memcpy(_sps, nalUnit.data + 4, _spsSize);
                NSLog(@"NALUint SPS size:%d", nalUnit.size - 4);
                break;
            case NALUTypePPS://PPS
                _ppsSize = nalUnit.size - 4;
                if(_ppsSize <= 0){
                    return NULL;
                }
                
                _pps = (uint8_t*)malloc(_ppsSize);
                memcpy(_pps, nalUnit.data + 4, _ppsSize);
                NSLog(@"NALUint PPS size:%d", nalUnit.size - 4);
                break;
            case NALUTypeBPFrame://B/P Frame
                pixelBufferRef = [self decompressWithAVPacket:packet];
                NSLog(@"NALUint B/P Frame size:%d", nalUnit.size);
                return pixelBufferRef;
            default:
                break;
        }
        
        offset += nalUnit.size;
        if(offset >= dataLen){
            return NULL;
        }
    }
    
    NSLog(@"The AVFrame data size:%d", offset);
    return NULL;
}

-(void)infalteStartCodeWithNalunitData:(NALUnit *)dataUnit
{
    //Inflate start code with data length
    unsigned char* data  = dataUnit->data;
    unsigned int dataLen = dataUnit->size - 4;
    
    data[0] = (unsigned char)(dataLen >> 24);
    data[1] = (unsigned char)(dataLen >> 16);
    data[2] = (unsigned char)(dataLen >> 8);
    data[3] = (unsigned char)(dataLen & 0xff);
}

-(int)nalunitWithData:(char *)data andDataLen:(int)dataLen andOffset:(int)offset toNALUnit:(NALUnit *)unit
{
    unit->size = 0;
    unit->data = NULL;
    
    
    int addUpLen = offset;
    while(addUpLen < dataLen)
    {
        if(data[addUpLen++] == 0x00 &&
           data[addUpLen++] == 0x00 &&
           data[addUpLen++] == 0x00 &&
           data[addUpLen++] == 0x01){//H264 start code
            
            int pos = addUpLen;
            while(pos < dataLen){//Find next NALU
                if(data[pos++] == 0x00 &&
                   data[pos++] == 0x00 &&
                   data[pos++] == 0x00 &&
                   data[pos++] == 0x01){
                    
                    break;
                }
            }
            
            unit->type = data[addUpLen] & 0x1f;
            if(pos == dataLen){
                unit->size = pos - addUpLen + 4;
            }else{
                unit->size = pos - addUpLen;
            }
            
            unit->data = (unsigned char*)&data[addUpLen - 4 ];
            return 1;
        }
    }
    return -1;
}

-(BOOL)initH264Decoder
{
    if(_decompressionSession){
        return true;
    }
    
    const uint8_t * const parameterSetPointers[2] = {_sps, _pps};
    const size_t parameterSetSizes[2] = {_spsSize, _ppsSize};
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2,//parameter count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4,//NAL start code size
                                                                          &(_decompressionFormatDesc));
    if(status == noErr){
        const void *keys[] = { kCVPixelBufferPixelFormatTypeKey};
        
        //kCVPixelFormatType_420YpCbCr8Planar is YUV420, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange is NV12
        uint32_t biPlanarType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
        const void *values[] = {CFNumberCreate(NULL, kCFNumberSInt32Type, &biPlanarType)};
        CFDictionaryRef attributes = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
        
        //Create decompression session
        VTDecompressionOutputCallbackRecord outputCallBaclRecord;
        outputCallBaclRecord.decompressionOutputRefCon = NULL;
        outputCallBaclRecord.decompressionOutputCallback = decompressionOutputCallbackRecord;
        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                              _decompressionFormatDesc,
                                              NULL,
                                              attributes,
                                              &outputCallBaclRecord,
                                              &_decompressionSession);
        CFRelease(attributes);
        if(status != noErr){
            return false;
        }
    }else{
        NSLog(@"Error code %d:Creates a format description for a video media stream described by H.264 parameter set NAL units.", (int)status);
        return false;
    }
    
    return true;
}

//Callback function:Return data when finished, the data includes decompress data、status and so on.
static void decompressionOutputCallbackRecord(void * CM_NULLABLE decompressionOutputRefCon,
                                              void * CM_NULLABLE sourceFrameRefCon,
                                              OSStatus status,
                                              VTDecodeInfoFlags infoFlags,
                                              CM_NULLABLE CVImageBufferRef imageBuffer,
                                              CMTime presentationTimeStamp,
                                              CMTime presentationDuration ){
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(imageBuffer);
}

-(CVPixelBufferRef)decompressWithNalUint:(NALUnit)dataUnit
{
    CMBlockBufferRef blockBufferRef = NULL;
    CVPixelBufferRef outputPixelBufferRef = NULL;
    
    //1.Fetch video data and generate CMBlockBuffer
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                         dataUnit.data,
                                                         dataUnit.size,
                                                         kCFAllocatorNull,
                                                         NULL,
                                                         0,
                                                         dataUnit.size,
                                                         0,
                                                         &blockBufferRef);
    //2.Create CMSampleBuffer
    if(status == kCMBlockBufferNoErr){
        CMSampleBufferRef sampleBufferRef = NULL;
        const size_t sampleSizes[] = {dataUnit.size};
        
        CMSampleTimingInfo timing = {CMTimeMakeWithSeconds(dataUnit.duration, 1),
            CMTimeMakeWithSeconds(dataUnit.pts, 1), CMTimeMakeWithSeconds(dataUnit.dts, 1)};
        
        OSStatus createStatus = CMSampleBufferCreate(kCFAllocatorDefault,
                                                     blockBufferRef,
                                                     true,
                                                     NULL,
                                                     NULL,
                                                     _decompressionFormatDesc,
                                                     1,
                                                     1,
                                                     &timing,
                                                     1,
                                                     sampleSizes,
                                                     &sampleBufferRef);
        
        //3.Create CVPixelBuffer
        if(createStatus == kCMBlockBufferNoErr && sampleBufferRef){
            VTDecodeFrameFlags frameFlags = 0;
            VTDecodeInfoFlags infoFlags = 0;
            
            OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(_decompressionSession,
                                                                      sampleBufferRef,
                                                                      frameFlags,
                                                                      &dataUnit,
                                                                      &infoFlags);
            
            if(decodeStatus != noErr){
                CFRelease(sampleBufferRef);
                CFRelease(blockBufferRef);
                outputPixelBufferRef = nil;
                return nil;
            }
            
            
            if(_isTakePicture){
                if(!_isSaveTakePictureImage){
                    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:outputPixelBufferRef];
                    CIContext *ciContext = [CIContext contextWithOptions:nil];
                    CGImageRef videoImage = [ciContext
                                             createCGImage:ciImage
                                             fromRect:CGRectMake(0, 0,
                                                                 CVPixelBufferGetWidth(outputPixelBufferRef),
                                                                 CVPixelBufferGetHeight(outputPixelBufferRef))];
                    
                    UIImage *uiImage = [UIImage imageWithCGImage:videoImage];
                    _isSaveTakePictureImage = [UIImageJPEGRepresentation(uiImage, 1.0) writeToFile:_saveTakePicturePath atomically:YES];
                    CGImageRelease(videoImage);
                }
            }
            CFRelease(sampleBufferRef);
        }
        CFRelease(blockBufferRef);
    }
    return outputPixelBufferRef;
}

-(CVPixelBufferRef)decompressWithAVPacket:(AVPacket *)packet
{
    CMBlockBufferRef blockBufferRef = NULL;
    CVPixelBufferRef outputPixelBufferRef = NULL;
    
    //1.Fetch video data and generate CMBlockBuffer
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                         packet->data,
                                                         packet->size,
                                                         kCFAllocatorNull,
                                                         NULL,
                                                         0,
                                                         packet->size,
                                                         0,
                                                         &blockBufferRef);
    //2.Create CMSampleBuffer
    if(status == kCMBlockBufferNoErr){
        CMSampleBufferRef sampleBufferRef = NULL;
        const size_t sampleSizes[] = {packet->size};
        
        CMSampleTimingInfo timing = {CMTimeMakeWithSeconds(packet->duration, 1),
            CMTimeMakeWithSeconds(packet->pts, 1), CMTimeMakeWithSeconds(packet->dts, 1)};
        
        OSStatus createStatus = CMSampleBufferCreate(kCFAllocatorDefault,
                                                     blockBufferRef,
                                                     true,
                                                     NULL,
                                                     NULL,
                                                     _decompressionFormatDesc,
                                                     1,
                                                     1,
                                                     &timing,
                                                     1,
                                                     sampleSizes,
                                                     &sampleBufferRef);
        
        //3.Create CVPixelBuffer
        if(createStatus == kCMBlockBufferNoErr && sampleBufferRef){
            VTDecodeFrameFlags frameFlags = 0;
            VTDecodeInfoFlags infoFlags = 0;
            
            OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(_decompressionSession,
                                                                      sampleBufferRef,
                                                                      frameFlags,
                                                                      &outputPixelBufferRef,
                                                                      &infoFlags);
            
            if(decodeStatus != noErr){
                CFRelease(sampleBufferRef);
                CFRelease(blockBufferRef);
                outputPixelBufferRef = nil;
                return nil;
            }
            
            
            if(_isTakePicture){
                if(!_isSaveTakePictureImage){
                    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:outputPixelBufferRef];
                    CIContext *ciContext = [CIContext contextWithOptions:nil];
                    CGImageRef videoImage = [ciContext
                                             createCGImage:ciImage
                                             fromRect:CGRectMake(0, 0,
                                                                 CVPixelBufferGetWidth(outputPixelBufferRef),
                                                                 CVPixelBufferGetHeight(outputPixelBufferRef))];
                    
                    UIImage *uiImage = [UIImage imageWithCGImage:videoImage];
                    _isSaveTakePictureImage = [UIImageJPEGRepresentation(uiImage, 1.0) writeToFile:_saveTakePicturePath atomically:YES];
                    CGImageRelease(videoImage);
                }
            }
            CFRelease(sampleBufferRef);
        }
        CFRelease(blockBufferRef);
    }
    return outputPixelBufferRef;
}

- (void)decompressWithPacket:(AVPacket *)packet Completed:(CYHwDecompressCompleted)completed
{
    if (!_decompressionSession)
    {
        return;
    }
    
    CMBlockBufferRef blockBufferRef = NULL;
    CVPixelBufferRef outputPixelBufferRef = NULL;
    
    //1.Fetch video data and generate CMBlockBuffer
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                         packet->data,
                                                         packet->size,
                                                         kCFAllocatorNull,
                                                         NULL,
                                                         0,
                                                         packet->size,
                                                         0,
                                                         &blockBufferRef);
    //2.Create CMSampleBuffer
    if(status == kCMBlockBufferNoErr){
        CMSampleBufferRef sampleBufferRef = NULL;
        const size_t sampleSizes[] = {packet->size};
  
        CMSampleTimingInfo timing = {CMTimeMakeWithSeconds(packet->duration, 1),
            CMTimeMakeWithSeconds(packet->pts, 1), CMTimeMakeWithSeconds(packet->dts, 1)};
        
        OSStatus createStatus = CMSampleBufferCreate(kCFAllocatorDefault,
                             blockBufferRef,
                             true,
                             NULL,
                             NULL,
                             _decompressionFormatDesc,
                             1,
                             1,
                             &timing,
                             1,
                             sampleSizes,
                             &sampleBufferRef);
        
        //3.Create CVPixelBuffer
        if(createStatus == kCMBlockBufferNoErr && sampleBufferRef){
            VTDecodeFrameFlags frameFlags = 0;
            VTDecodeInfoFlags infoFlags = 0;
            
            CFAbsoluteTime startTime =CFAbsoluteTimeGetCurrent();
            
            OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(_decompressionSession,
                                                                      sampleBufferRef,
                                                                      frameFlags,
                                                                      &outputPixelBufferRef,
                                                                      &infoFlags);
            
            if(decodeStatus != noErr){
                completed(NULL, packet->pts, packet->duration);
                CFRelease(sampleBufferRef);
                CFRelease(blockBufferRef);
                outputPixelBufferRef = nil;
                return;
            }
            CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
#ifdef DEBUG
            NSLog(@"VTDecompressionSessionDecodeFrame in %.2f ms", linkTime * 1000.0);
#endif
            completed(outputPixelBufferRef, packet->pts, packet->duration);
            CVPixelBufferRelease(outputPixelBufferRef);
            CFRelease(sampleBufferRef);
        }
        CFRelease(blockBufferRef);
    }
}

-(void)dealloc
{
    if(_sps){
        free(_sps);
        _sps = NULL;
    }
    
    if(_pps){
        free(_pps);
        _pps = NULL;
    }
    
    if(_decompressionSession){
        VTDecompressionSessionInvalidate(_decompressionSession);
        CFRelease(_decompressionSession);
        _decompressionSession = NULL;
    }
    
    if(_decompressionFormatDesc){
        CFRelease(_decompressionFormatDesc);
        _decompressionFormatDesc = NULL;
    }
}

# pragma mark - Test API
- (id)initWithCodecCtx:(AVCodecContext *)codecCtx
{
    if (self = [super init])
    {
        self.canHWDecompressing = [self initH264DecoderWithCodecCtx:codecCtx];
    }
    return self;
}

- (BOOL)initH264DecoderWithCodecCtx:(AVCodecContext *)codec
{
    if(_decompressionSession){
        return true;
    }
    
//    NSMutableDictionary * atoms = [[NSMutableDictionary alloc] initWithCapacity:1];
//    [atoms setValue:[NSData dataWithBytes:codec->extradata length:codec->extradata_size] forKey:@"avcC"];
//
//    NSMutableDictionary * extensions = [[NSMutableDictionary alloc] initWithCapacity:1];
//    [extensions setValue:atoms forKey:@"SampleDescriptionExtensionAtoms"];
//    OSStatus status = CMVideoFormatDescriptionCreate(
//                                                     NULL,
//                                                     kCMVideoCodecType_H264,
//                                                     codec->width,
//                                                     codec->height,
//                                                     (__bridge CFDictionaryRef _Nullable)(extensions),
//                                                     &(_decompressionFormatDesc));
    
//    (char*)malloc(sizeof(char)*n)
    uint8_t *sps = NULL;
    int spsLen = 0;
    int sps_start_index = 0;
    int sps_index = -1;
    while ((++sps_index) < codec->extradata_size)
    {
        if (codec->extradata[sps_start_index] != 0x67 && codec->extradata[sps_start_index] != 0x27)
        {
            sps_start_index ++;
        }
    }
    
    uint8_t *pps = NULL;
    int ppsLen = 0;
    int pps_start_index = codec->extradata_size > 0 ? (codec->extradata_size - 1) : 0;
    int pps_index = codec->extradata_size;
    while ((--pps_index) >= 0)
    {
        if (codec->extradata[pps_start_index] != 0x68 && codec->extradata[pps_start_index] != 0x28)
        {
            pps_start_index --;
        }
    }
    
    if ((codec->extradata_size > 0) && (sps_start_index != pps_start_index))
    {
        ppsLen = ABS(codec->extradata_size - pps_start_index);
        if (ppsLen < 4)
        {
            if (*(codec->extradata + (codec->extradata_size - 4)) == 0x68 || *(codec->extradata + (codec->extradata_size - 4)) == 0x28) {
                ppsLen = 4;
                pps_start_index = ABS(codec->extradata_size - 4);
            }
        }
        spsLen = ABS(pps_start_index - sps_start_index);
        
        
        sps = (uint8_t*)malloc(sizeof(uint8_t)*spsLen);
        pps = (uint8_t*)malloc(sizeof(uint8_t)*ppsLen);
        
        memcpy(sps,  (codec->extradata + sps_start_index), spsLen);
        memcpy(pps,  (codec->extradata + pps_start_index), ppsLen);
    }
    
    const uint8_t * const parameterSetPointers[2] = {sps, pps};
    const size_t parameterSetSizes[2] = {spsLen, ppsLen};
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2,//parameter count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4,//NAL start code size
                                                                          &(_decompressionFormatDesc));
    
    
    
    if(status == noErr){
        _sps = sps;
        _pps = pps;
        // 指定VT必须使 的解码
        CFMutableDictionaryRef decoderParam = CFDictionaryCreateMutable(NULL,
                                                                        0,
                                                                        &kCFTypeDictionaryKeyCallBacks,
                                                                        &kCFTypeDictionaryValueCallBacks);
        
        // 设置解码后视频帧的格式(包括颜 空间、宽 等)
        CFMutableDictionaryRef destinationPixelAttributes = CFDictionaryCreateMutable(NULL,
                                                                                      0,
                                                                                      &kCFTypeDictionaryKeyCallBacks,
                                                                                      &kCFTypeDictionaryValueCallBacks);
        
        SInt32 destinationPixelType = kCVPixelFormatType_420YpCbCr8Planar;
        int tmpWidth = codec->width;
        int tmpHeight = codec->height;
        
        CFDictionarySetValue(destinationPixelAttributes,
                             kCVPixelBufferPixelFormatTypeKey,
                             CFNumberCreate(NULL,
                                            kCFNumberSInt32Type,
                                            &destinationPixelType));
        CFDictionarySetValue(destinationPixelAttributes,
                             kCVPixelBufferWidthKey,
                             CFNumberCreate(NULL,
                                            kCFNumberSInt32Type,
                                            &tmpWidth));
        CFDictionarySetValue(destinationPixelAttributes,
                             kCVPixelBufferHeightKey,
                             CFNumberCreate(NULL,
                                            kCFNumberSInt32Type,
                                            &tmpHeight));
        
        // 创建解码的session
        // 最后一个参数是返回值，也就是解码的session对象，在之后的解码与释放等流程都会使  到
        VTDecompressionOutputCallbackRecord outputCallBaclRecord;
        outputCallBaclRecord.decompressionOutputRefCon = NULL;
        outputCallBaclRecord.decompressionOutputCallback = decompressionOutputCallbackRecord;
        
        status = VTDecompressionSessionCreate(NULL,
                                              _decompressionFormatDesc,
                                              decoderParam,
                                              destinationPixelAttributes,
                                              &outputCallBaclRecord,
                                              &_decompressionSession);
        
        CFRelease(destinationPixelAttributes);
        CFRelease(decoderParam);
        
//        const void *keys[] = { kCVPixelBufferPixelFormatTypeKey};
//
//        //kCVPixelFormatType_420YpCbCr8Planar is YUV420, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange is NV12
//        uint32_t biPlanarType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
//        const void *values[] = {CFNumberCreate(NULL, kCFNumberSInt32Type, &biPlanarType)};
//        CFDictionaryRef attributes = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
//
//        //Create decompression session
//
//        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
//                                              _decompressionFormatDesc,
//                                              NULL,
//                                              attributes,
//                                              &outputCallBaclRecord,
//                                              &_decompressionSession);
//
//        CFRelease(attributes);
        if(status != noErr){
            return false;
        }
    }else{
        NSLog(@"Error code %d:Creates a format description for a video media stream described by H.264 parameter set NAL units.", (int)status);
        return false;
    }
    
    return true;
}


@end

