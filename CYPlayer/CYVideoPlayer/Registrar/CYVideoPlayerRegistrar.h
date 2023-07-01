//
//  CYVideoPlayerRegistrar.h
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/12/5.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, CYVideoPlayerBackstageState) {
    CYVideoPlayerBackstageState_Forground,  // 从后台进入前台
    CYVideoPlayerBackstageState_Background, // 从前台进入后台
};

@interface CYVideoPlayerRegistrar : NSObject

@property (nonatomic, assign, readonly) CYVideoPlayerBackstageState state;

@property (nonatomic, copy, readwrite, nullable) void(^willResignActive)(CYVideoPlayerRegistrar *registrar);

@property (nonatomic, copy, readwrite, nullable) void(^didBecomeActive)(CYVideoPlayerRegistrar *registrar);

@property (nonatomic, copy, readwrite, nullable) void(^newDeviceAvailable)(CYVideoPlayerRegistrar *registrar);

@property (nonatomic, copy, readwrite, nullable) void(^oldDeviceUnavailable)(CYVideoPlayerRegistrar *registrar);

@property (nonatomic, copy, readwrite, nullable) void(^categoryChange)(CYVideoPlayerRegistrar *registrar);

@end

NS_ASSUME_NONNULL_END
