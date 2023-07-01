//
//  CYLabelSlider.h
//  CYSlider
//
//  Created by yellowei on 2017/11/20.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYCommonSlider.h"

@interface CYLabelSlider : CYCommonSlider

@property (nonatomic, strong, readonly) UILabel *leftLabel;
@property (nonatomic, strong, readonly) UILabel *rightlabel;

@end
