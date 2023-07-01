//
//  UIResponder+CYExtension.h
//  CYPlayer
//
//  Created by 黄威 on 2017/12/25.
//  Copyright © 2017年 黄威. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIResponder (CYExtension)

@property (nonatomic, assign, readwrite, getter=isLockRotation) BOOL lockRotation;

@property (nonatomic, assign, readwrite, getter=isAllowRotation) BOOL allowRotation;

@end
