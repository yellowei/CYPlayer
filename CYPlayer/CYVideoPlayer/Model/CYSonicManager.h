//
//  CYSonicManager.h
//  CYPlayer
//
//  Created by 杨倩 on 2020/6/22.
//  Copyright © 2020 Sutan. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN



@interface CYSonicManager : NSObject


@property(nonatomic,assign) double m_samplerate;               //采样率
@property(nonatomic,assign) NSInteger m_channel;                  //声道数
@property(nonatomic,assign) double playRate;
@property(nonatomic,assign) double playSpeed;

+ (CYSonicManager *) sonicManager;

- (NSData *)setShortData:(NSData *)data;
- (NSData *)setFloatData:(NSData *)data;
- (void)destroySonic;

@end

NS_ASSUME_NONNULL_END
