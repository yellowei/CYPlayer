//
//  UIViewController+CYExtension.m
//  CYPlayer
//
//  Created by 黄威 on 2017/12/25.
//  Copyright © 2017年 黄威. All rights reserved.
//

#import "UIViewController+CYExtension.h"
#import "UIResponder+CYExtension.h"
#import <objc/message.h>

@implementation UIViewController (CYExtension)

- (void)setLandSpace:(BOOL)landSpace
{
    if ( self.isLandSpace == landSpace )
    {
        return;
    }
    objc_setAssociatedObject(self, @selector(isLandSpace), @(landSpace), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
}

- (BOOL)isLandSpace {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}


# pragma mark - 横屏控制

//强制横屏
-(void)forceForLandscape
{
    UIResponder *delegate = (UIResponder *)[UIApplication sharedApplication].delegate;
    delegate.allowRotation = YES;
    [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger: UIDeviceOrientationLandscapeLeft] forKey:@"orientation"];
    self.landSpace = YES;
}

-(void)forceForPortrait
{
    [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger: UIDeviceOrientationPortrait] forKey:@"orientation"];
}

//取消强制横屏
-(void)cancelForceLandscape
{
    [self closeLandscape];
    [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger: UIDeviceOrientationPortrait] forKey:@"orientation"];
    self.landSpace = NO;
}

-(void)openLandscape
{
    UIResponder *delegate =   (UIResponder *)[UIApplication sharedApplication].delegate;
    delegate.allowRotation = YES;
}




-(void)closeLandscape
{
    UIResponder *delegate = (UIResponder *)[UIApplication sharedApplication].delegate;
    delegate.allowRotation = NO;
}

-(void)lockRotation
{
    UIResponder *delegate =   (UIResponder *)[UIApplication sharedApplication].delegate;
    delegate.lockRotation = YES;
}

-(void)unlockRotation
{
    UIResponder *delegate =   (UIResponder *)[UIApplication sharedApplication].delegate;
    delegate.lockRotation = NO;
}



@end
