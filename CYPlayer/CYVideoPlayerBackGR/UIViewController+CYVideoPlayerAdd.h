//
//  UIViewController+CYVideoPlayerAdd.h
//  CYBackGR
//
//  Created by yellowei on 2017/9/27.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIViewController (CYVideoPlayerAdd)

/*!
 *  The specified area does not trigger gestures.
 *  In the array is subview frame.
 *  @[@(self.label.frame), @(self.btn.frame)]
 *
 *  指定区域不触发手势.
 **/
@property (nonatomic, strong) NSArray<NSValue *> *cy_fadeArea;

@property (nonatomic, strong) NSArray<UIView *> *cy_fadeAreaViews;

@property (nonatomic, copy, readwrite) void(^cy_viewWillBeginDragging)(__kindof UIViewController *vc);
@property (nonatomic, copy, readwrite) void(^cy_viewDidDrag)(__kindof UIViewController *vc);
@property (nonatomic, copy, readwrite) void(^cy_viewDidEndDragging)(__kindof UIViewController *vc);

@end
