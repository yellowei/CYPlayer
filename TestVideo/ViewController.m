//
//  ViewController.m
//  TestVideo
//
//  Created by Admin on 12/21/14.
//  Copyright (c) 2014 Sutan. All rights reserved.
//

#import "ViewController.h"
#import "PlayerViewController.h"
#import "RTSPViewController.h"
#import <Masonry.h>
#import "MainViewController.h"
#import "CYFFmpegViewController.h"
#import "UIViewController+CYExtension.h"
#import "CYPCMAudioManager.h"
#import "CYTest.h"


@implementation ViewController



- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self closeLandscape];
    
    UIButton * btn1 = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn1 addTarget:self action:@selector(onTouch:) forControlEvents:UIControlEventTouchUpInside];
    btn1.backgroundColor = [UIColor blackColor];
    [btn1 setTitle:@"播放网络" forState:UIControlStateNormal];
    btn1.tag = 100;
    btn1.layer.cornerRadius = 5.0;
    [self.view addSubview:btn1];
    [btn1 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.equalTo(@(100));
        make.top.equalTo(@100);
        make.centerX.equalTo(@(0));
    }];
    
    UIButton * btn2 = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn2 addTarget:self action:@selector(onTouch:) forControlEvents:UIControlEventTouchUpInside];
    btn2.backgroundColor = [UIColor blackColor];
    [btn2 setTitle:@"播放列表" forState:UIControlStateNormal];
    btn2.tag = 200;
    btn2.layer.cornerRadius = 5.0;
    [self.view addSubview:btn2];
    [btn2 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.equalTo(@(100));
        make.top.equalTo(btn1.mas_bottom).offset(10);
        make.centerX.equalTo(@0);
    }];
    
    UIButton * btn3 = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn3 addTarget:self action:@selector(onTouch:) forControlEvents:UIControlEventTouchUpInside];
    btn3.backgroundColor = [UIColor blackColor];
    [btn3 setTitle:@"播放RTSP" forState:UIControlStateNormal];
    btn3.tag = 300;
    btn3.layer.cornerRadius = 5.0;
    [self.view addSubview:btn3];
    [btn3 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.equalTo(@(100));
        make.top.equalTo(btn2.mas_bottom).offset(10);
        make.centerX.equalTo(@0);
    }];
    

}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)onTouch:(UIButton *)sender
{
    //    [self presentViewController:[[PlayerViewController alloc] init] animated:YES completion:nil];
    if (sender.tag == 100) {
//        PlayerViewController * pvc = [[PlayerViewController alloc] init];
//        pvc.assetURL = [NSURL URLWithString:@"http://static.tripbe.com/videofiles/20121214/9533522808.f4v.mp4"];
//        [self.navigationController pushViewController:pvc animated:YES];
        [CYTest testSMB];
    }
    else if (sender.tag == 200) {
//        PlayerViewController * pvc = [[PlayerViewController alloc] init];
//        NSString * path = [[NSBundle mainBundle] pathForResource:@"01" ofType:@"avi"];
//        pvc.assetURL = [NSURL fileURLWithPath:path];
//        [self.navigationController pushViewController:pvc animated:YES];
        UIViewController *vc = [[MainViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
    }
    else if (sender.tag == 300) {
//        CYPCMAudioManager * audio = [CYPCMAudioManager audioManager];
//        for (NSInteger i = 0; i <= 490; i++)
//        {
//            [audio setFilePath:[[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"%ld", i] ofType:@"pcm"]];
//        }
        
//        RTSPViewController * vc = [[RTSPViewController alloc] init];
////        UIViewController *vc = [[MainViewController alloc] init];
////        UIViewController *vc = [[CYFFmpegViewController alloc] init];
////        
//        [self.navigationController pushViewController:vc animated:YES];
        [CYTest testGeneratedPreviewImagesWithImagesCount];
    }
}

@end
