//
//  CYCommonSlider.h
//  CYSlider
//
//  Created by yellowei on 2017/11/20.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CYSlider.h"

@interface CYCommonSlider : UIView

@property (nonatomic, strong, readonly) UIView *leftContainerView;
@property (nonatomic, strong, readonly) CYSlider *slider;
@property (nonatomic, strong, readonly) UIView *rightContainerView;

@end
