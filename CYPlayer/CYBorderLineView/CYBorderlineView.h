//
//  CYBorderlineView.h
//  CYLine
//
//  Created by yellowei on 2017/6/11.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, CYBorderlineSide) {
    CYBorderlineSideNone     = 0,
    CYBorderlineSideTop      = 1 << 0,
    CYBorderlineSideLeading  = 1 << 1,
    CYBorderlineSideTrailing = 1 << 2,
    CYBorderlineSideBottom   = 1 << 3,
    CYBorderlineSideAll      = 1 << 4,
};

@interface CYBorderlineView : UIView

+ (instancetype)borderlineViewWithSide:(CYBorderlineSide)side startMargin:(CGFloat)startMargin endMargin:(CGFloat)endMargin lineColor:(UIColor *)color backgroundColor:(UIColor *)backgroundColor;

+ (instancetype)borderlineViewWithSide:(CYBorderlineSide)side startMargin:(CGFloat)startMargin endMargin:(CGFloat)endMargin lineColor:(UIColor *)color lineWidth:(CGFloat)width backgroundColor:(UIColor *)backgroundColor;



// MARK: Change

@property (nonatomic, strong, readwrite) UIColor *lineColor;

@property (nonatomic, assign, readwrite) CGFloat lineWidth;

@property (nonatomic, assign, readwrite) CYBorderlineSide side;

- (void)setStartMargin:(CGFloat)startMargin endMargin:(CGFloat)endMargin;

/*!
 *  if you changed property. you should call this method.
 */
- (void)update;

@end

