//
//  ComicListViewController.m
//  xkcd Open Source
//
//  Created by Mike on 5/14/15.
//  Copyright (c) 2015 Mike Amaral. All rights reserved.
//

#import "ComicListViewController.h"
#import <UIView+Facade.h>
#import "DataManager.h"
#import "ThemeManager.h"
#import "LoadingView.h"
#import "Comic.h"
#import "ComicCell.h"
#import "ComicWebViewController.h"
#import "AltView.h"

static NSString * const kComicListTitle = @"xkcd: Open Source";
static NSString * const kNoSearchResultsMessage = @"No results found...";
static NSString * const kNoFavoritesMessage = @"You have no favorites yet!";

static CGFloat const kRandomComicButtonSize = 60.0;

@interface ComicListViewController ()

@property (nonatomic, strong) AltView *altView;

@end

@implementation ComicListViewController

- (instancetype)init {
    ComicListFlowLayout *comicListLayout = [ComicListFlowLayout new];
    comicListLayout.delegate = self;
    return [super initWithCollectionViewLayout:comicListLayout];
}


#pragma mark - View life cycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = kComicListTitle;
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    self.navigationController.navigationBar.backIndicatorImage = [ThemeManager backImage];
    self.navigationController.navigationBar.backIndicatorTransitionMaskImage = [ThemeManager backImage];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.collectionView.backgroundColor = [ThemeManager xkcdLightBlue];
    [self.collectionView registerClass:[ComicCell class] forCellWithReuseIdentifier:kComicCellReuseIdentifier];

    self.altView = [AltView new];
    self.altView.alpha = 0.0;

    self.searchButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(toggleSearch)];
    self.navigationItem.leftBarButtonItem = self.searchButton;

    [self setFilterFavoritesButtonOn:NO];

    self.searchBar = [UISearchBar new];
    self.searchBar.delegate = self;
    self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;

    self.noResultsLabel = [UILabel new];
    self.noResultsLabel.hidden = YES;
    self.noResultsLabel.text = kNoSearchResultsMessage;
    self.noResultsLabel.font = [ThemeManager xkcdFontWithSize:18];
    self.noResultsLabel.textColor = [UIColor blackColor];
    self.noResultsLabel.textAlignment = NSTextAlignmentCenter;
    [self.collectionView addSubview:self.noResultsLabel];

    self.randomComicButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.randomComicButton setImage:[ThemeManager randomImage] forState:UIControlStateNormal];
    self.randomComicButton.imageEdgeInsets = UIEdgeInsetsMake(1, 1, 1, 1);
    self.randomComicButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    self.randomComicButton.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    [self.randomComicButton addTarget:self action:@selector(showRandomComic) forControlEvents:UIControlEventTouchUpInside];
    [self.randomComicButton setBackgroundColor:[ThemeManager xkcdLightBlue]];
    [self.view addSubview:self.randomComicButton];

    [ThemeManager addBorderToLayer:self.randomComicButton.layer radius:kRandomComicButtonSize / 2.0 color:[UIColor whiteColor]];
    [ThemeManager addShadowToLayer:self.randomComicButton.layer radius:10.0 opacity:0.6];

    // Initially we want to grab what we have stored.
    [self loadComicsFromDB];

    // Fetch comics whenever we get notified more are available.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadComicsFromDB) name:NewComicsAvailableNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // If we don't have any comics and we're not filtering/searching, it's the first launch - let's show the loading view
    // and wait for the data manager to tell us new comics are available.
    if (!self.searching && self.comics.count == 0 && ![LoadingView isVisible] && !self.filteringFavorites) {
        [self handleInitialLoadBegan];
    }

    // If we're filtering favorites, fetch an updated list just in case something was unfavorited.
    if (self.filteringFavorites) {
        [self filterFavorites];
    } else if (!self.searching) {
        [self loadComicsFromDB];
    } else {
        [self.collectionView reloadData];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // Clear the app badge here, as we can be reasonably sure at this point anything new
    // will have been seen, and we won't run into annoying issues related to the app
    // life-cycle that we've experienced before.
    if ([UIApplication sharedApplication].applicationIconBadgeNumber > 0) {
        [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    }
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];

    if ([LoadingView isVisible]) {
        [LoadingView handleLayoutChanged];
    }

    if (!self.noResultsLabel.isHidden) {
        [self.noResultsLabel anchorTopCenterFillingWidthWithLeftAndRightPadding:15 topPadding:15 height:20];
    }

    [self.randomComicButton anchorBottomRightWithRightPadding:15 bottomPadding:15 width:kRandomComicButtonSize height:kRandomComicButtonSize];
}


#pragma mark - Loading data

- (void)loadComicsFromDB {
    // Grab the comics we have saved.
    self.comics = [[DataManager sharedInstance] allSavedComics];

    // If we have comics and the loading view is present, tell it to handle that we're done.
    if (self.comics.count > 0 && [LoadingView isVisible]) {
        [self handleInitialLoadEnded];
    }

    // Reload the collection view.
    [self.collectionView reloadData];
}

- (void)handleInitialLoadBegan {
    self.navigationItem.leftBarButtonItem.enabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;

    [LoadingView showInView:self.view];
}

- (void)handleInitialLoadEnded {
    self.navigationItem.leftBarButtonItem.enabled = YES;
    self.navigationItem.rightBarButtonItem.enabled = YES;

    [LoadingView handleDoneLoading];
}


#pragma mark - Actions

- (void)showComic:(Comic *)comic atIndexPath:(NSIndexPath *)indexPath {
    ComicViewController *comicVC = [ComicViewController new];
    comicVC.delegate = self;
    comicVC.allowComicNavigation = !self.searching && !self.filteringFavorites;
    comicVC.comic = comic;
    [self.navigationController pushViewController:comicVC animated:YES];
}

- (void)showRandomComic {
    [self cancelAllNavBarActions];

    [self.randomComicButton setImage:[ThemeManager randomImage] forState:UIControlStateNormal];

    [self showComic:[[DataManager sharedInstance] randomComic] atIndexPath:nil];
}


#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.comics.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    ComicCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kComicCellReuseIdentifier forIndexPath:indexPath];
    cell.comic = self.comics[indexPath.item];
    cell.delegate = self;
    return cell;
}


#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    Comic *comic = self.comics[indexPath.item];

    if (comic.isInteractive || [[DataManager sharedInstance].knownInteractiveComicNumbers containsObject:@(comic.num)]) {
        ComicWebViewController *comicWebVC = [ComicWebViewController new];
        comicWebVC.comic = comic;
        [self.navigationController pushViewController:comicWebVC animated:YES];
    } else {
        [self showComic:comic atIndexPath:indexPath];
    }
}


#pragma mark - Layout delegate

- (CGFloat)collectionView:(UICollectionView *)collectionView relativeHeightForItemAtIndexPath:(NSIndexPath *)indexPath {
    Comic *comic = self.comics[indexPath.item];
    CGFloat aspectRatio = comic.aspectRatio;
    return 1.0 / aspectRatio;
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldBeDoubleColumnAtIndexPath:(NSIndexPath *)indexPath {
    Comic *comic = self.comics[indexPath.item];
    CGFloat aspectRatio = comic.aspectRatio;
    return aspectRatio > 1.0;
}

- (NSUInteger)numberOfColumnsInCollectionView:(UICollectionView *)collectionView {
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    BOOL isLandscape = UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation);
    
    if (isPad) {
        return isLandscape ? 6 : 4;
    } else {
        return isLandscape ? 4 : 2;
    }
}


#pragma mark - Comic view controller delegate

- (Comic *)comicViewController:(ComicViewController *)comicViewController comicBeforeCurrentComic:(Comic *)currentComic {
    NSInteger indexOfCurrentComic = [self.comics indexOfObject:currentComic];

    return (indexOfCurrentComic != NSNotFound && indexOfCurrentComic > 0) ? self.comics[indexOfCurrentComic - 1] : nil;
}

- (Comic *)comicViewController:(ComicViewController *)comicViewController comicAfterCurrentComic:(Comic *)currentComic {
    NSInteger indexOfCurrentComic = [self.comics indexOfObject:currentComic];

    return (indexOfCurrentComic != NSNotFound && indexOfCurrentComic + 1 <= self.comics.count - 1) ? self.comics[indexOfCurrentComic + 1] : nil;
}

- (Comic *)comicViewController:(ComicViewController *)comicViewController randomComic:(Comic *)currentComic {
    return [[DataManager sharedInstance] randomComic];
}


#pragma mark - Searching and Filtering

- (void)toggleSearch {
    if (!self.searching) {
        self.searching = YES;
        self.filteringFavorites = NO;

        [self enableSearch];
    } else {
        [self cancelAllNavBarActions];
    }
}

- (void)toggleFilterFavorites:(UIBarButtonItem *)favoritesButton {
    if (!self.filteringFavorites) {
        [self setFilterFavoritesButtonOn:YES];

        self.filteringFavorites = YES;
        self.searching = NO;

        [self filterFavorites];
    } else {
        [self cancelAllNavBarActions];
    }
}

- (void)setFilterFavoritesButtonOn:(BOOL)on {
    UIImage *favoriteButtonImage = on ? [ThemeManager favoriteImage] : [ThemeManager favoriteOffImage];

    self.filterFavoritesButton = [[UIBarButtonItem alloc] initWithImage:[favoriteButtonImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] landscapeImagePhone:nil style:UIBarButtonItemStylePlain target:self action:@selector(toggleFilterFavorites:)];
    self.filterFavoritesButton.imageInsets = UIEdgeInsetsMake(10, 10, 10, 10);

    self.navigationItem.rightBarButtonItem = self.filterFavoritesButton;
}

- (void)enableSearch {
    [self.searchBar becomeFirstResponder];

    self.navigationItem.titleView = self.searchBar;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelAllNavBarActions)];
}

- (void)searchForComicsWithSearchString:(NSString *)searchString {
    self.comics = [[DataManager sharedInstance] comicsMatchingSearchString:searchString];

    self.noResultsLabel.text = kNoSearchResultsMessage;

    [self handleSearchOrFilterCompleteWithScroll:YES];
}

- (void)filterFavorites {
    self.comics = [[DataManager sharedInstance] allFavorites];

    self.noResultsLabel.text = kNoFavoritesMessage;

    [self handleSearchOrFilterCompleteWithScroll:NO];
}

- (void)handleSearchOrFilterCompleteWithScroll:(BOOL)scroll {
    if (self.comics.count > 0) {
        self.noResultsLabel.hidden = YES;

        if (scroll) {
            [self.collectionView setContentOffset:CGPointZero animated:YES];
        }
    } else {
        self.noResultsLabel.hidden = NO;
    }

    [self.collectionView reloadData];
}


#pragma mark - Comic cell delegate

- (void)comicCell:(ComicCell *)cell didSelectComicAltWithComic:(Comic *)comic {
    if (!self.altView.isVisible) {
        self.altView.comic = comic;
        [self.altView showInView:self.view];
    } else {
        self.altView.comic = nil;
        [self.altView dismiss];
    }
}


#pragma mark - Nav bar state

- (void)cancelAllNavBarActions {
    self.searching = NO;
    self.filteringFavorites = NO;
    self.searchBar.text = @"";
    self.comics = [[DataManager sharedInstance] allSavedComics];
    self.noResultsLabel.hidden = YES;

    self.navigationItem.leftBarButtonItem = self.searchButton;
    self.navigationItem.titleView = nil;

    [self setFilterFavoritesButtonOn:NO];

    [self.collectionView setContentOffset:CGPointZero animated:YES];
    [self.collectionView reloadData];
}



#pragma mark - UISearchBar delegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self searchForComicsWithSearchString:searchBar.text];
}

@end
