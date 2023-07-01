//
//  UIView+CYUIFactory.m
//  CYUIFactory
//
//  Created by yellowei on 2017/11/25.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "UIView+CYUIFactory.h"
#import <objc/message.h>

@implementation UIView (CYUIFactory)

- (void)setCcy_x:(CGFloat)ccy_x {
    CGRect frame    = self.frame;
    frame.origin.x  = ccy_x;
    self.frame      = frame;
}
- (CGFloat)ccy_x {
    return self.frame.origin.x;
}


- (void)setCcy_y:(CGFloat)ccy_y {
    CGRect frame    = self.frame;
    frame.origin.y  = ccy_y;
    self.frame      = frame;
}
- (CGFloat)ccy_y {
    return self.frame.origin.y;
}


- (void)setCcy_w:(CGFloat)ccy_w {
    CGRect frame        = self.frame;
    frame.size.width    = ccy_w;
    self.frame          = frame;
}
- (CGFloat)ccy_w {
    return self.frame.size.width;
}


- (void)setCcy_h:(CGFloat)ccy_h {
    CGRect frame        = self.frame;
    frame.size.height   = ccy_h;
    self.frame          = frame;
}
- (CGFloat)ccy_h {
    return self.frame.size.height;
}

- (void)setCcy_size:(CGSize)ccy_size {
    CGRect frame        = self.frame;
    frame.size          = ccy_size;
    self.frame          = frame;
    
}
- (CGSize)ccy_size {
    return self.frame.size;
}

- (void)setCcy_centerX:(CGFloat)ccy_centerX {
    CGPoint center  = self.center;
    center.x        = ccy_centerX;
    self.center     = center;
}
- (CGFloat)ccy_centerX {
    return self.center.x;
}


- (void)setCcy_centerY:(CGFloat)ccy_centerY {
    CGPoint center  = self.center;
    center.y        = ccy_centerY;
    self.center     = center;
}
- (CGFloat)ccy_centerY {
    return self.center.y;
}

- (CGFloat)ccy_maxX {
    return self.ccy_x + self.ccy_w;
}

- (CGFloat)ccy_maxY {
    return self.ccy_y + self.ccy_h;
}

- (UIViewController *)ccy_viewController {
    UIResponder *responder = self.nextResponder;
    while ( ![responder isKindOfClass:[UIViewController class]] ) {
        responder = responder.nextResponder;
        if ( [responder isMemberOfClass:[UIResponder class]] ) return nil;
    }
    return (UIViewController *)responder;
}

@end
