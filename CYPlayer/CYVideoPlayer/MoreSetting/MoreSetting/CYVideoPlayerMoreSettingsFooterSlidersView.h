//
//  CYVideoPlayerMoreSettingsFooterSlidersView.h
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/9/25.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CYMoreSettingsFooterViewModel.h"


NS_ASSUME_NONNULL_BEGIN

@interface CYVideoPlayerMoreSettingsFooterSlidersView : UICollectionReusableView

@property (nonatomic, weak, readwrite) CYMoreSettingsFooterViewModel *model;

@end

NS_ASSUME_NONNULL_END
