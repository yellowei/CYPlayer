//
//  ViewController.h
//  cyplayerapp
//
//  Created by Kolyvan on 11.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/cyplayer
//  this file is part of CYPlayer
//  CYPlayer is licenced under the LGPL v3, see lgpl-3.0.txt

#import <UIKit/UIKit.h>

@class CYPlayerDecoder;

extern NSString * const CYPlayerParameterMinBufferedDuration;    // Float
extern NSString * const CYPlayerParameterMaxBufferedDuration;    // Float
extern NSString * const CYPlayerParameterDisableDeinterlacing;   // BOOL

@interface CYPlayerViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>

+ (id) movieViewControllerWithContentPath: (NSString *) path
                               parameters: (NSDictionary *) parameters;

@property (readonly) BOOL playing;

- (void) play;
- (void) pause;

@end
