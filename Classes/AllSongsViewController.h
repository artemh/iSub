//
//  AllSongsViewController.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "SUSLoaderDelegate.h"

@class Song, Album, SUSAllSongsDAO, LoadingScreen, EGORefreshTableHeaderView;

@interface AllSongsViewController : UITableViewController <UISearchBarDelegate, SUSLoaderDelegate> 
{
	
	SUSAllSongsDAO *dataModel;
	
	UIView *headerView;
	UIButton *reloadButton;
	UILabel *reloadLabel;
	UIImageView *reloadImage;
	UILabel *countLabel;
	UILabel *reloadTimeLabel;
	IBOutlet UISearchBar *searchBar;
	
	BOOL letUserSelectRow;
	NSURL *url;
		
	NSInteger numberOfRows;
	
	NSArray *sectionInfo;
	
	BOOL isSearching;
		
	BOOL isProcessingArtists;
	
	EGORefreshTableHeaderView *refreshHeaderView;
	BOOL _reloading;
	
	UIView *searchOverlay;
	UIButton *dismissButton;
}

@property (retain) SUSAllSongsDAO *dataModel;

@property (retain) UIView *headerView;
@property (retain) NSArray *sectionInfo;

@property (retain) LoadingScreen *loadingScreen;

- (void) addCount;

- (void) doneSearching_Clicked:(id)sender;

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error;
- (void)loadingFinished:(SUSLoader*)theLoader;

- (void)dataSourceDidFinishLoadingNewData;

- (void)showLoadingScreen;
- (void)hideLoadingScreen;

@end