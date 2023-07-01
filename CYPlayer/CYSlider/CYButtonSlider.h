//
//  CYButtonSlider.h
//  CYSlider
//
//  Created by yellowei on 2017/11/20.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYCommonSlider.h"

@interface CYButtonSlider : CYCommonSlider

@property (nonatomic, strong, readonly) UIButton *leftBtn;
@property (nonatomic, strong, readonly) UIButton *rightBtn;

@property (nonatomic, strong, readwrite) NSString *leftText;
@property (nonatomic, strong, readwrite) NSString *rightText;

@property (nonatomic, strong, readwrite) UIColor *titleColor;

@end
