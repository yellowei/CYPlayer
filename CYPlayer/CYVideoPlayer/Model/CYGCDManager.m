//
//  CYGCDManager.m
//  AFNetworking
//
//  Created by yellowei on 2020/8/28.
//

#import "CYGCDManager.h"

@implementation CYGCDManager


+ (CYGCDManager *) sharedManager
{
    static CYGCDManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[CYGCDManager alloc] init];
        sharedManager.av_read_frame_lock = dispatch_semaphore_create(1);//初始化锁
        sharedManager.decode_preview_images_frames_av_read_frame_lock = dispatch_semaphore_create(1);//初始化锁
        sharedManager.av_send_receive_packet_lock = dispatch_semaphore_create(1);//初始化锁
        sharedManager.swr_context_lock = dispatch_semaphore_create(1);//初始化锁
        sharedManager.sws_context_lock = dispatch_semaphore_create(1);//初始化锁
        sharedManager.generate_preview_images_dispatch_queue = dispatch_queue_create("CYPlayer_GeneratedPreviewImagesDispatchQueue", DISPATCH_QUEUE_CONCURRENT);
        sharedManager.concurrent_decode_queue = dispatch_queue_create("Con-Current Decode Queue", DISPATCH_QUEUE_CONCURRENT);
        sharedManager.concurrent_group = dispatch_group_create();
        sharedManager.setter_getter_concurrent_queue = dispatch_queue_create("Con-Current Setter/Getter Queue", DISPATCH_QUEUE_CONCURRENT);
    });
    return sharedManager;
}

# pragma mark - Getter/Setter


@end
