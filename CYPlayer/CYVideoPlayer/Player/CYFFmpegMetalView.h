//
//  CYFFmpegMetalView.h
//  CYPlayer
//
//  Created by yellowei on 2020/1/13.
//  Copyright © 2020 Sutan. All rights reserved.
//

@import MetalKit;
@import GLKit;

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

# pragma mark - CYFFmpegMetalView

@interface CYFFmpegMetalView : UIView

- (void)renderWithPixelBuffer:(CVPixelBufferRef)buffer;

@end

NS_ASSUME_NONNULL_END
