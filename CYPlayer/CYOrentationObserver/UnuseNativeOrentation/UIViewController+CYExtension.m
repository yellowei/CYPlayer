//
//  UIViewController+CYExtension.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/9/8.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "UIViewController+CYExtension.h"

@implementation UIViewController (CYExtension)

- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

@end
