//
//  CYGCDManager.h
//  AFNetworking
//
//  Created by yellowei on 2020/8/28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CYGCDManager : NSObject

//高可用接口
@property (nonatomic, strong) dispatch_semaphore_t av_read_frame_lock;
@property (nonatomic, strong) dispatch_semaphore_t decode_preview_images_frames_av_read_frame_lock;
@property (nonatomic, strong) dispatch_semaphore_t av_send_receive_packet_lock;
@property (nonatomic, strong) dispatch_queue_t    concurrent_decode_queue;
@property (nonatomic, strong) dispatch_group_t    concurrent_group;
@property (nonatomic, strong) dispatch_queue_t  setter_getter_concurrent_queue;
@property (nonatomic, strong) dispatch_semaphore_t swr_context_lock;
@property (nonatomic, strong) dispatch_semaphore_t sws_context_lock;
@property (nonatomic, strong) dispatch_queue_t    generate_preview_images_dispatch_queue;

+ (CYGCDManager *) sharedManager;

@end

NS_ASSUME_NONNULL_END
