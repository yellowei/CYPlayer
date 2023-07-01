//
//  CYVideoPlayerControlViewEnumHeader.h
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/9/25.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#ifndef CYVideoPlayerControlViewEnumHeader_h
#define CYVideoPlayerControlViewEnumHeader_h

typedef NS_ENUM(NSUInteger, CYVideoPlayControlViewTag) {
    CYVideoPlayControlViewTag_Back,
    CYVideoPlayControlViewTag_Full,
    CYVideoPlayControlViewTag_Play,
    CYVideoPlayControlViewTag_Pause,
    CYVideoPlayControlViewTag_Replay,
    CYVideoPlayControlViewTag_Preview,
    CYVideoPlayControlViewTag_Lock,
    CYVideoPlayControlViewTag_Unlock,
    CYVideoPlayControlViewTag_LoadFailed,
    CYVideoPlayControlViewTag_More,
};




typedef NS_ENUM(NSUInteger, CYVideoPlaySliderTag) {
    CYVideoPlaySliderTag_Volume,
    CYVideoPlaySliderTag_Brightness,
    CYVideoPlaySliderTag_Rate,
    CYVideoPlaySliderTag_Progress,
    CYVideoPlaySliderTag_Dragging,
};


//#define CY_S_W ([UIScreen mainScreen].bounds.size.width)
//#define CY_S_H ([UIScreen mainScreen].bounds.size.height)
//#define CY_is_iPhone_X (MIN(CY_S_W, CY_S_H) / MAX(CY_S_W, CY_S_H) == 1125.0 / 2436)

#endif /* CYVideoPlayerControlViewEnumHeader_h */
