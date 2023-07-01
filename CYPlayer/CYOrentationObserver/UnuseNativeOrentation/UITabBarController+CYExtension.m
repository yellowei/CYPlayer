//
//  UITabBarController+CYExtension.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/9/8.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "UITabBarController+CYExtension.h"

@implementation UITabBarController (CYExtension)

- (BOOL)shouldAutorotate {
    UIViewController *vc = self.viewControllers[self.selectedIndex];
    if ( [vc isKindOfClass:[UINavigationController class]] )
         return [((UINavigationController *)vc).topViewController shouldAutorotate];
    else return [vc shouldAutorotate];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    UIViewController *vc = self.viewControllers[self.selectedIndex];
    if ( [vc isKindOfClass:[UINavigationController class]] )
         return ((UINavigationController *)vc).topViewController.supportedInterfaceOrientations;
    else return vc.supportedInterfaceOrientations;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    UIViewController *vc = self.viewControllers[self.selectedIndex];
    if ( [vc isKindOfClass:[UINavigationController class]] )
        return ((UINavigationController *)vc).topViewController.preferredInterfaceOrientationForPresentation;
    else
        return vc.preferredInterfaceOrientationForPresentation;
}

@end
