//
//  RTSPViewController.m
//  CYPlayer
//
//  Created by 黄威 on 2018/7/17.
//  Copyright © 2018年 Sutan. All rights reserved.
//

#import "RTSPViewController.h"
#import "CYRtspPlayer.h"

@interface RTSPViewController ()
@property (nonatomic, strong) NSTimer *nextFrameTimer;
@end

@implementation RTSPViewController

@synthesize video;
@synthesize cy_video;
@synthesize image;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    self.image = [[UIImageView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.image];
    
    __weak typeof(self)weakSelf = self;
#if DEBUG
    dispatch_async(dispatch_get_main_queue(), ^{
//        NSString * path = [[NSBundle mainBundle] pathForResource:@"01" ofType:@"avi"];
//        NSURL * url = [NSURL fileURLWithPath:path];
//        NSString * video_str = [url absoluteString];
        
//        weakSelf.cy_video = [[CYRtspPlayer alloc] initWithVideo:@"http://static.tripbe.com/videofiles/20121214/9533522808.f4v.mp4"];
        weakSelf.cy_video = [[CYRtspPlayer alloc] initWithVideo:@"rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov"];
        weakSelf.cy_video.outputWidth = 426;
        weakSelf.cy_video.outputHeight = 320;
        
        [weakSelf.nextFrameTimer invalidate];
        weakSelf.nextFrameTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/weakSelf.cy_video.fps
                                                                   target:self
                                                                 selector:@selector(displayNextFrame:)
                                                                 userInfo:nil
                                                                  repeats:YES];
    });
#else

//    dispatch_async(dispatch_get_main_queue(), ^{
//        NSString * path = [[NSBundle mainBundle] pathForResource:@"01" ofType:@"avi"];
//        NSURL * url = [NSURL fileURLWithPath:path];
//        NSString * video_str = [url absoluteString];
////        weakSelf.video = [[RTSPPlayer alloc] initWithVideo:@"rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov" usesTcp:YES];
//        weakSelf.video = [[CYRtspPlayer alloc] initWithVideo:video_str usesTcp:YES];
//        weakSelf.video.outputWidth = 426;
//        weakSelf.video.outputHeight = 320;
//        
//        [weakSelf.nextFrameTimer invalidate];
//        weakSelf.nextFrameTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/weakSelf.video.fps
//                                                               target:self
//                                                             selector:@selector(displayNextFrame:)
//                                                             userInfo:nil
//                                                              repeats:YES];
//    });
#endif
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)viewWillAppear:(BOOL)animated {
    
}

- (void)viewDidDisappear:(BOOL)animated {
    [_nextFrameTimer invalidate];
    self.nextFrameTimer = nil;
}
-(void)displayNextFrame:(NSTimer *)timer
{
//    if (![video stepFrame]) {
//        [timer invalidate];
//        [video closeAudio];
//        return;
//    }
//    image.image = cy_video.currentImage;
    if (![cy_video stepFrame]) {
        [timer invalidate];
        [cy_video closeAudio];
        return;
    }
    image.image = cy_video.currentImage;
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
