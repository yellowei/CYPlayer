//
//  UIViewController+CYExtension.h
//  CYPlayer
//
//  Created by 黄威 on 2017/12/25.
//  Copyright © 2017年 黄威. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIViewController (CYExtension)

@property (nonatomic, assign, readonly, getter=isLandSpace) BOOL landSpace;

-(void)forceForLandscape;

-(void)forceForPortrait;

-(void)cancelForceLandscape;

-(void)openLandscape;

-(void)closeLandscape;


-(void)unlockRotation;

-(void)lockRotation;

@end
