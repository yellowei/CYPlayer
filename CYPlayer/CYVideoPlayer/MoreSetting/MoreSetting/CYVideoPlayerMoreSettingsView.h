//
//  CYVideoPlayerMoreSettingsView.h
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/9/25.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CYMoreSettingsFooterViewModel.h"

NS_ASSUME_NONNULL_BEGIN

@class CYVideoPlayerMoreSettingsFooterSlidersView, CYVideoPlayerMoreSetting, CYSlider;

@interface CYVideoPlayerMoreSettingsView : UIView

@property (nonatomic, strong, readwrite, nullable) NSArray<CYVideoPlayerMoreSetting *> *moreSettings;

@property (nonatomic, strong, readwrite, nullable) CYMoreSettingsFooterViewModel *footerViewModel;

@end

NS_ASSUME_NONNULL_END
