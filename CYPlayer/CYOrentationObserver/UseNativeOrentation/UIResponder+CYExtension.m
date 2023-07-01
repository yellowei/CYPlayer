//
//  UIResponder+CYExtension.m
//  CYPlayer
//
//  Created by 黄威 on 2017/12/25.
//  Copyright © 2017年 黄威. All rights reserved.
//

#import "UIResponder+CYExtension.h"
#import <objc/message.h>

@implementation UIResponder (CYExtension)

- (void)setLockRotation:(BOOL)lockRotation
{
    if ( self.isLockRotation == lockRotation )
    {
        return;
    }
    objc_setAssociatedObject(self, @selector(isLockRotation), @(lockRotation), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
}

- (BOOL)isLockRotation {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setAllowRotation:(BOOL)allowRotation
{
    if ( self.isAllowRotation == allowRotation )
    {
        return;
    }
    objc_setAssociatedObject(self, @selector(isAllowRotation), @(allowRotation), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
}

- (BOOL)isAllowRotation {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

# pragma mark - 横屏控制

- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window
{
    if (self.isLockRotation)
    {
        return UIInterfaceOrientationMaskLandscape;
    }
    
    if (self.isAllowRotation)
    {
        return UIInterfaceOrientationMaskAll;
    }
    else
    {
        NSNumber *value = [NSNumber numberWithInt:UIInterfaceOrientationPortrait];
        [[UIDevice currentDevice] setValue:value forKey:@"orientation"];
        
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
        return UIInterfaceOrientationMaskPortrait;
    }
}


@end
