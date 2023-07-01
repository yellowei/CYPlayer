//
//  CYSlider.h
//  dancebaby
//
//  Created by yellowei on 2017/6/12.
//  Copyright © 2017年 SanJing. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol CYSliderDelegate;

@interface CYSlider : UIView

/*!
 *  default is YES.
 */
@property (nonatomic, assign, readwrite) BOOL isRound;

/*!
 *  轨道
 *  this is view, If you don't want to set up photos, You can set the background color.
 */
@property (nonatomic, strong, readonly) UIImageView *trackImageView;

/*!
 *  走过的痕迹
 *  this is view, If you don't want to set up photos, You can set the background color.
 */
@property (nonatomic, strong, readonly) UIImageView *traceImageView;

/*!
 *  拇指
 *  If you do not set the image, it will not display.
 */
@property (nonatomic, strong, readonly) UIImageView *thumbImageView;
@property (nonatomic, strong) UIImage *thumbnail_nor;
@property (nonatomic, strong) UIImage *thumbnail_sel;


/*!
 *  当前进度值
 *  current Value
 */
@property (nonatomic, assign, readwrite) CGFloat value;

/*!
 *  设置轨道高度. 
 *  default is 8.0;
 */
@property (nonatomic, assign, readwrite) CGFloat trackHeight;

/*!
 *  最小值. 
 *  default is 0.0;
 */
@property (nonatomic, assign, readwrite) CGFloat minValue;

/*!
 *  最大值. 
 *  default is 1.0;
 */
@property (nonatomic, assign, readwrite) CGFloat maxValue;

@property (nonatomic, weak) id <CYSliderDelegate>delegate;

/*!
 *  触动手势
 *  If you don't want to use this gesture, you can disable it
 *  pan.enable = NO.
 */
@property (nonatomic, strong, readonly) UIPanGestureRecognizer *pan;
@property (nonatomic, strong, readonly) UITapGestureRecognizer *tap;

/*!
 *  slider是否被拖拽
 */
@property (nonatomic, assign, readonly) BOOL isDragging;

@end



#pragma mark - Border


@interface CYSlider (BorderLine)

/*!
 *  visual border line.
 *  default is NO.
 */
@property (nonatomic, assign, readwrite) BOOL visualBorder;

/*!
 *  borderColor
 *  default is lightGrayColor.
 */
@property (nonatomic, strong, readwrite) UIColor *borderColor;

/*!
 *  borderWidth
 *  default is 0.4.
 */
@property (nonatomic, assign, readwrite) CGFloat borderWidth;

@end



#pragma mark - Buffer


@interface CYSlider (CYBufferProgress)

/*!
 *  开启缓冲进度. default is NO.
 */
@property (nonatomic, assign, readwrite) BOOL enableBufferProgress;

/*!
 *  缓冲进度颜色. default is grayColor
 */
@property (nonatomic, strong, readwrite) UIColor *bufferProgressColor;

/*!
 *  缓冲进度
 */
@property (nonatomic, assign, readwrite) CGFloat bufferProgress;

@end


#pragma mark - Delegate


@protocol CYSliderDelegate <NSObject>

@optional

/*!
 * 点击
 */
- (void)sliderClick:(CYSlider *)slider;

/*!
 *  开始滑动
 */
- (void)sliderWillBeginDragging:(CYSlider *)slider;

/*!
 *  正在滑动
 */
- (void)sliderDidDrag:(CYSlider *)slider;

/*!
 *  滑动完成
 */
- (void)sliderDidEndDragging:(CYSlider *)slider;

@end
