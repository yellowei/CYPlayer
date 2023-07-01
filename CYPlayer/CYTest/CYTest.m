//
//  CYTest.m
//  CYPlayer
//
//  Created by 黄威 on 2018/8/16.
//  Copyright © 2018年 Sutan. All rights reserved.
//

#import "CYTest.h"
#import <CYFFmpeg/CYFFmpeg.h>
#import "CYPlayer.h"
//#import "x264.h"


@implementation CYTest
#ifdef SMBCLIENT_H_INCLUDED
static void my_smbc_get_auth_data_with_context_fn(SMBCCTX *c,
                                                  const char *srv,
                                                  const char *shr,
                                                  char *workgroup, int wglen,
                                                  char *username, int unlen,
                                                  char *password, int pwlen)
{
    void * data = smbc_getOptionUserData(c);
////    if (username) {
////           {
////               strncpy(username, "guest", unlen - 1);
////           }
////       }
//
//       if (password) {
//           {
//               password[0] = 0;
//           }
//       }
//
//       if (workgroup) {
//           {
//               workgroup[0] = 0;
//           }
//       }
}



+ (void)testSMB
{
    SMBCCTX * ctx = smbc_new_context();
    if (!ctx) {
        NSLog(@"smbc_new_context failed");
    }
    
    if (!smbc_init_context(ctx))
    {
        NSLog(@"smbc_init_context failed");
    }
    smbc_set_context(ctx);
    
    smbc_setOptionUserData(ctx, @"work");
    smbc_setTimeout(ctx,3000);
    smbc_setFunctionAuthDataWithContext(ctx, my_smbc_get_auth_data_with_context_fn);
    //    smbc_setOptionUserData(ctx, h);
    //    smbc_setFunctionAuthDataWithContext(libsmbc->ctx, libsmbc_get_auth_data);
    
    
    if (smbc_init(NULL, 0) < 0) {
        NSLog(@"smbc_init failed");
    }
    
    //    smbc_get_auth_data_fn fn;
    //    int debug;
    //    smbc_init(fn, debug);
    
    
    //当制定了密码,不会走
    // | O_WRONLY 注意权限问题my_smbc_get_auth_data_with_context_fn
    if ((smbc_open("smb://workgroup;mobile:123123@172.16.9.10/video/test.mp4", O_RDONLY, 0666)) < 0) {
        NSLog(@"File open failed");
    }
    else
    {
        NSLog(@"File open successed");
    }
    //
    //    x264_encoder_encode(NULL, NULL, NULL, NULL, NULL);
    
    //    avcodec_open2(NULL, NULL, NULL);
}

#endif

+ (void)testGeneratedPreviewImagesWithImagesCount
{
    [CYPlayerDecoder generatedPreviewImagesWithPath:@"smb://mobile:123123@172.16.9.10/video/test.mp4" time:20 completionHandler:^(NSMutableArray *frames, NSError *error) {
        
    }];
    
}

@end
