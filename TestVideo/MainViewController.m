//
//  MainViewController.m
//  cyplayer
//
//  Created by Kolyvan on 18.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/cyplayer
//  this file is part of CYPlayer
//  CYPlayer is licenced under the LGPL v3, see lgpl-3.0.txt

#import "MainViewController.h"
#import "CYMovieViewController.h"
#import "CYFFmpegViewController.h"

@interface MainViewController () {
    NSArray *_localMovies;
    NSArray *_remoteMovies;
}
@property (strong, nonatomic) UITableView *tableView;
@end

@implementation MainViewController

- (id)init
{
    self = [super init];
    if (self) {
        self.title = @"FFmpegPlayer";
        self.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemFeatured tag: 0];
        NSString * localV = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"mp4"];
        NSString * localV1 = [[NSBundle mainBundle] pathForResource:@"4k60" ofType:@"mp4"];
        NSString * localV2 = [[NSBundle mainBundle] pathForResource:@"5k120" ofType:@"mkv"];
        _remoteMovies = @[
            localV,localV1,localV2,
            @"http://vodplay.yellowei360.com/liveRecord/46eca58c0ccf5b857fa76cb3c9fea487/dentalink-vod/515197938314592256/2020-08-17-12-18-39_2020-08-17-12-48-39.m3u8",
            @"https://vodplay.yellowei360.com/liveRecord/46eca58c0ccf5b857fa76cb3c9fea487/dentalink-vod/515197938314592256/2020-08-17-12-18-39_2020-08-17-12-48-39.m3u8",
            @"rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov",
            @"http://static.tripbe.com/videofiles/20121214/9533522808.f4v.mp4",
            @"rtmp://live.hkstv.hk.lxdns.com/live/hks",
            @"http://live.hkstv.hk.lxdns.com/live/hks/playlist.m3u8",
            @"http://ivi.bupt.edu.cn/hls/cctv1hd.m3u8",
            @"http://ivi.bupt.edu.cn/hls/cctv3hd.m3u8",
            @"http://ivi.bupt.edu.cn/hls/cctv5hd.m3u8",
            @"http://ivi.bupt.edu.cn/hls/cctv5phd.m3u8",
            @"http://ivi.bupt.edu.cn/hls/cctv6hd.m3u8",
            @"http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_4x3/gear2/prog_index.m3u8",
            @"rtsp://184.72.239.149/vod/mp4://BigBuckBunny_175k.mov",
            @"rtsp://218.204.223.237:554/live/1/66251FC11353191F/e7ooqwcfbqjoo80j.sdp",
            @"rtmp://rtmp.yayiguanjia.com/AppName/StreamName?auth_key=1533608675-0-0-4708840ac7649d449d643a25156f7be7",
            @"smb://192.168.31.217/Downloads/a.avi",
            @"smb://192.168.31.217/Downloads/9533522808.f4v.mp4",
            @"smb://192.168.31.217/Downloads/9533522808.f4v.AVI",
            @"http://vodplay.yellowei360.com/8f391c8d78ea4ef29319c5e5792c40d9/550c2ee07572458c83eeaad6f03229ce-592802bc25e1f9ea794d2180107eb14b-hd.mp4",
            @"http://dtcollege.oss-cn-qingdao.aliyuncs.com/5/23/8/88/304368212387233792_merge.m4a",
            @"smb://guest@172.16.9.10/video/test.mp4",
            @"smb://WORKGROUP;yellowei:1314-Wamq@192.168.31.170/Movie/Marval Movie/04 Thor 2011 BluRay 720p DTS x264-MgB [ETRG].mkv",
            @"rtmp://play2.yellowei360.com/dentalink-vod/530504197284757504_lld?auth_key=1601306667-0-0-79a7fb3d8c2e075ce6843cc7d310f18f"
        ];
        
    }
    return self;
}

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor whiteColor];
    //self.tableView.backgroundView = [[UIImageView alloc] initWithImage:image];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    
    [self.view addSubview:self.tableView];
}

- (BOOL)prefersStatusBarHidden { return YES; }

- (void)viewDidLoad
{
    [super viewDidLoad];
    
#ifdef DEBUG_AUTOPLAY
    [self performSelector:@selector(launchDebugTest) withObject:nil afterDelay:0.5];
#endif
}

- (void)launchDebugTest
{
    [self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:4
                                                                              inSection:1]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    //    [self reloadMovies];
    [self.tableView reloadData];
}

- (void) reloadMovies
{
    NSMutableArray *ma = [NSMutableArray array];
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString *folder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                            NSUserDomainMask,
                                                            YES) lastObject];
    NSArray *contents = [fm contentsOfDirectoryAtPath:folder error:nil];
    
    for (NSString *filename in contents) {
        
        if (filename.length > 0 &&
            [filename characterAtIndex:0] != '.') {
            
            NSString *path = [folder stringByAppendingPathComponent:filename];
            NSDictionary *attr = [fm attributesOfItemAtPath:path error:nil];
            if (attr) {
                id fileType = [attr valueForKey:NSFileType];
                if ([fileType isEqual: NSFileTypeRegular] ||
                    [fileType isEqual: NSFileTypeSymbolicLink]) {
                    
                    NSString *ext = path.pathExtension.lowercaseString;
                    
                    if ([ext isEqualToString:@"mp3"] ||
                        [ext isEqualToString:@"caff"]||
                        [ext isEqualToString:@"aiff"]||
                        [ext isEqualToString:@"ogg"] ||
                        [ext isEqualToString:@"wma"] ||
                        [ext isEqualToString:@"m4a"] ||
                        [ext isEqualToString:@"m4v"] ||
                        [ext isEqualToString:@"wmv"] ||
                        [ext isEqualToString:@"3gp"] ||
                        [ext isEqualToString:@"mp4"] ||
                        [ext isEqualToString:@"mov"] ||
                        [ext isEqualToString:@"avi"] ||
                        [ext isEqualToString:@"mkv"] ||
                        [ext isEqualToString:@"mpeg"]||
                        [ext isEqualToString:@"mpg"] ||
                        [ext isEqualToString:@"flv"] ||
                        [ext isEqualToString:@"vob"]) {
                        
                        [ma addObject:path];
                    }
                }
            }
        }
    }
    
    // Add all the movies present in the app bundle.
    NSBundle *bundle = [NSBundle mainBundle];
    [ma addObjectsFromArray:[bundle pathsForResourcesOfType:@"mp4" inDirectory:@"SampleMovies"]];
    [ma addObjectsFromArray:[bundle pathsForResourcesOfType:@"mov" inDirectory:@"SampleMovies"]];
    [ma addObjectsFromArray:[bundle pathsForResourcesOfType:@"m4v" inDirectory:@"SampleMovies"]];
    [ma addObjectsFromArray:[bundle pathsForResourcesOfType:@"wav" inDirectory:@"SampleMovies"]];
    
    [ma sortedArrayUsingSelector:@selector(compare:)];
    
    _localMovies = [ma copy];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0:     return @"Remote";
        case 1:     return @"Local";
    }
    return @"";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:     return _remoteMovies.count;
        case 1:     return _localMovies.count;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"Cell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:cellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    NSString *path;
    
    if (indexPath.section == 0) {
        
        path = _remoteMovies[indexPath.row];
        
    } else {
        
        path = _localMovies[indexPath.row];
    }
    
    cell.textLabel.text = path.lastPathComponent;
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *path;
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    if (indexPath.section == 0) {
        
        if (indexPath.row >= _remoteMovies.count) return;
        path = _remoteMovies[indexPath.row];
        
    } else {
        
        if (indexPath.row >= _localMovies.count) return;
        path = _localMovies[indexPath.row];
    }
    
    // increase buffering for .wmv, it solves problem with delaying audio frames
    if ([path.pathExtension isEqualToString:@"wmv"])
        parameters[CYPlayerParameterMinBufferedDuration] = @(5.0);
    
    // disable deinterlacing for iPhone, because it's complex operation can cause stuttering
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        parameters[CYPlayerParameterDisableDeinterlacing] = @(YES);
    
    // disable buffering
    //parameters[CYPlayerParameterMinBufferedDuration] = @(0.0f);
    //parameters[CYPlayerParameterMaxBufferedDuration] = @(0.0f);
    
    //    CYPlayerViewController *vc = [CYPlayerViewController movieViewControllerWithContentPath:path
    //                                                                               parameters:parameters];
    CYFFmpegViewController * vc = [[CYFFmpegViewController alloc] init];
    vc.path = path;
    [self.navigationController pushViewController:vc animated:YES];
    //    [self presentViewController:vc animated:YES completion:nil];
    //[self.navigationController pushViewController:vc animated:YES];
    
    //    LoggerApp(1, @"Playing a movie: %@", path);
}

@end
