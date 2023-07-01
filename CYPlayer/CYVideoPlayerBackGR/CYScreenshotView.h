//
//  CYScreenshotView.h
//  CYBackGR
//
//  Created by yellowei on 2017/9/27.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CYScreenshotView : UIView

@property (nonatomic, strong) UIImage *image;

- (void)setShadeAlpha:(CGFloat)alpha;

@end
