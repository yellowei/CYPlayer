//
//  CYVideoPlayerSelectTableView.m
//  CYPlayer
//
//  Created by yellowei on 2020/1/6.
//  Copyright © 2020 Sutan. All rights reserved.
//

#import "CYVideoPlayerSelectTableView.h"
#import "CYUIFactory.h"
#import <Masonry/Masonry.h>


@interface CYVideoPlayerSelectTableView()<UITableViewDataSource, UITableViewDelegate>



@end

@implementation CYVideoPlayerSelectTableView

@synthesize selectTableView = _selectTableView;


- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    [self _selectTableSetupViews];
    __weak typeof(self) _self = self;
    self.setting = ^(CYVideoPlayerSettings * _Nonnull setting) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
    };
    return self;
}


# pragma mark - Private Methods
- (void)_selectTableSetupViews
{
    [self.containerView addSubview:self.selectTableView];
    
    [_selectTableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.containerView);
    }];
}


# pragma mark - Public Methods
- (void)reloadTableView
{
    [self.selectTableView reloadData];
}

- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.selectTableView scrollToRowAtIndexPath:indexPath atScrollPosition:(UITableViewScrollPositionMiddle) animated:YES];
}

# pragma mark - Getter/Setter
- (UITableView *)selectTableView
{
    if (_selectTableView) return _selectTableView;
    _selectTableView = [CYUITableViewFactory tableViewWithStyle:UITableViewStylePlain backgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.5] separatorStyle:UITableViewCellSeparatorStyleSingleLineEtched showsVerticalScrollIndicator:YES delegate:self dataSource:self];
    return _selectTableView;
}

# pragma mark - <UITableViewDataSource, UITableViewDelegate>
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.numberOfSectionsInTableView)
    {
        return self.numberOfSectionsInTableView(tableView);
    }
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.numberOfRowsInSection) {
        return self.numberOfRowsInSection(tableView, section);
    }
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(self.cellForRowAtIndexPath, @"CYVideoPlayerSelectTableView CellForRowAtIndexPath Block Not Nil");
    return self.cellForRowAtIndexPath(tableView, indexPath);
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.heightForRowAtIndexPath) {
        return self.heightForRowAtIndexPath(tableView, indexPath);
    }
    return 44.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (self.heightForHeaderInSection) {
        return self.heightForHeaderInSection(tableView, section);
    }
    return 0.01;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (self.heightForFooterInSection) {
        return self.heightForFooterInSection(tableView, section);
    }
    return 0.01;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.didSelectRowAtIndexPath)
    {
        self.didSelectRowAtIndexPath(tableView, indexPath);
    }
}

@end
