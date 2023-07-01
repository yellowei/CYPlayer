//
//  CYVideoPlayerState.h
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/11/29.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#ifndef CYVideoPlayerState_h
#define CYVideoPlayerState_h

typedef NS_ENUM(NSUInteger, CYVideoPlayerPlayState) {
    CYVideoPlayerPlayState_Unknown = 0,
    CYVideoPlayerPlayState_Prepare,
    CYVideoPlayerPlayState_Playing,
    CYVideoPlayerPlayState_Buffing,
    CYVideoPlayerPlayState_Pause,
    CYVideoPlayerPlayState_PlayEnd,
    CYVideoPlayerPlayState_PlayFailed,
    CYVideoPlayerPlayState_Ready,
};

#endif /* CYVideoPlayerState_h */
