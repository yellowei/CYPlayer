//
//  UIView+CYUIFactory.h
//  CYUIFactory
//
//  Created by yellowei on 2017/11/25.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView (CYUIFactory)

@property (nonatomic, assign) CGFloat ccy_x;
@property (nonatomic, assign) CGFloat ccy_y;
@property (nonatomic, assign) CGFloat ccy_w;
@property (nonatomic, assign) CGFloat ccy_h;
@property (nonatomic, assign) CGSize  ccy_size;
@property (nonatomic, assign) CGFloat ccy_centerX;
@property (nonatomic, assign) CGFloat ccy_centerY;
@property (nonatomic, assign, readonly) CGFloat ccy_maxX;
@property (nonatomic, assign, readonly) CGFloat ccy_maxY;
@property (nonatomic, strong, readonly, nullable) UIViewController *ccy_viewController;

@end

NS_ASSUME_NONNULL_END
