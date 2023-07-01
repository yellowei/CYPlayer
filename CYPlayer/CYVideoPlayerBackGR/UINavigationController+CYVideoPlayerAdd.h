//
//  UINavigationController+CYVideoPlayerAdd.h
//  CYBackGR
//
//  Created by yellowei on 2017/9/26.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface UINavigationController (CYVideoPlayerAdd)<UIGestureRecognizerDelegate>

@property (nonatomic, strong, readonly) UIPanGestureRecognizer *cy_pan;

@end





@interface UINavigationController (Settings)

/*!
 *  bar Color
 *
 *  如果导航栏上出现了黑底, 请设置他.
 **/
@property (nonatomic, strong, readwrite) UIColor *cy_backgroundColor;

/*!
 *  default is NO.
 *  If you use native gestures, some methods(cy_viewWillBeginDragging...) of the controller will not be called.
 *  使用系统边缘返回手势, 还是使用自定义的全屏手势
 **/
@property (nonatomic, assign, readwrite) BOOL useNativeGesture;

/*!
 *  default is 0.35.
 *
 *  0.0 .. 1.0
 *  偏移多少, 触发pop操作
 **/
@property (nonatomic, assign, readwrite) float scMaxOffset;

/*!
 *  default is NO.
 *
 *  禁用系统手势和全屏手势.
 **/
@property (nonatomic, assign, readwrite) BOOL cy_DisableGestures;

@end
