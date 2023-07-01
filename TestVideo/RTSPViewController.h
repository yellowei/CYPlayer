//
//  RTSPViewController.h
//  CYPlayer
//
//  Created by 黄威 on 2018/7/17.
//  Copyright © 2018年 Sutan. All rights reserved.
//

#import <UIKit/UIKit.h>
@class RTSPPlayer, CYRtspPlayer;

@interface RTSPViewController : UIViewController

@property (nonatomic, strong) RTSPPlayer *video;
@property (nonatomic, strong) CYRtspPlayer *cy_video;
@property (strong, nonatomic) UIImageView *image;

@end
