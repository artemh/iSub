//
//  RootViewController.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "FoldersViewController.h"
#import "SearchOverlayViewController.h"
#import "iSubAppDelegate.h"
#import "MusicSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "AlbumViewController.h"
#import "Artist.h"
#import "LoadingScreen.h"
#import "ArtistUITableViewCell.h"
#import "NSString+md5.h"
#import "FMDatabaseAdditions.h"
#import "ViewObjectsSingleton.h"
#import "UIView+Tools.h"
#import "CustomUIAlertView.h"
#import "EGORefreshTableHeaderView.h"
#import <QuartzCore/QuartzCore.h>
#import "FolderDropdownControl.h"
#import "SUSRootFoldersDAO.h"
#import "SavedSettings.h"
#import "FlurryAnalytics.h"
#import "SUSAllSongsLoader.h"
#import "SeparaterView.h"
#import "NSArray+Additions.h"
#import "UIViewController+PushViewController.h"

@interface FoldersViewController (Private)

- (void)dataSourceDidFinishLoadingNewData;
- (void)addCount;
-(void)loadData:(NSNumber *)folderId;

@end

@implementation FoldersViewController

@synthesize searchBar, headerView;
//@synthesize indexes, folders, foldersSearch;
@synthesize isSearching;
@synthesize dropdown;

@synthesize reloading=_reloading;

@synthesize dataModel;

#pragma mark - Rotation

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if ([SavedSettings sharedInstance].isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.1];
	
	searchOverlayView.view.y += 40.0;
 
	[UIView commitAnimations];
}

#pragma mark - Lifecycle

- (void)createDataModel
{
	self.dataModel = [[[SUSRootFoldersDAO alloc] initWithDelegate:self] autorelease];
	dataModel.selectedFolderId = [[SavedSettings sharedInstance] rootFoldersSelectedFolderId];
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicSingleton sharedInstance];
	settings = [SavedSettings sharedInstance];
	
	[self createDataModel];
	
	self.title = @"Folders";
		
	//Set defaults
	isSearching = NO;
	letUserSelectRow = YES;	
	isCountShowing = NO;
	searchY = 80;
	dropdown = nil;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverSwitched) name:ISMSNotification_ServerSwitched object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(doneSearching_Clicked:) name:@"endSearch" object:searchOverlayView];
	
	// Add the pull to refresh view
	refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, 320.0f, self.tableView.bounds.size.height)];
	refreshHeaderView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:237.0/255.0 alpha:1.0];
	[self.tableView addSubview:refreshHeaderView];
	[refreshHeaderView release];
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	else
	{		
		if (dropdown.folders == nil || [dropdown.folders count] == 2)
			[self.tableView setContentOffset:CGPointMake(0, 86) animated:NO];
		else
			[self.tableView setContentOffset:CGPointMake(0, 50) animated:NO];
	}	
		UIImageView *fadeBottom = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
		fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
		fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.tableView.tableFooterView = fadeBottom;
	 //}
	
	if ([dataModel isRootFolderIdCached])
		[self addCount];
}

-(void)viewWillAppear:(BOOL)animated 
{
	[super viewWillAppear:animated];
	
	if(musicControls.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	if (![SUSAllSongsLoader isLoading] && !viewObjects.isArtistsLoading)
	{
		if (![dataModel isRootFolderIdCached])
		{
			[self loadData:[[SavedSettings sharedInstance] rootFoldersSelectedFolderId]];
		}
	}
	
	[FlurryAnalytics logEvent:@"FoldersTab"];
	
	DLog(@"view subviews: %@", self.view.subviews);
	DLog(@"view: %@   tableView: %@", self.view, self.tableView);
	DLog(@"view sublayers: %@", self.view.layer.sublayers);
	DLog(@"tableView sublayers: %@", self.tableView.layer.sublayers);
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}


- (void)viewDidUnload {
	// Release anything that can be recreated in viewDidLoad or on demand.
	// e.g. self.myOutlet = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"endSearch" object:searchOverlayView];
    
}


- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_ServerSwitched object:nil];

	dataModel.delegate = nil;
	[dataModel release]; dataModel = nil;
	[searchBar release]; searchBar = nil;
	[searchOverlayView release]; searchOverlayView = nil;
	[dropdown release]; dropdown = nil;
    [super dealloc];
}

#pragma mark - Loading

- (void)updateCount
{
	if ([dataModel count] == 1)
		countLabel.text = [NSString stringWithFormat:@"%i Folder", [dataModel count]];
	else
		countLabel.text = [NSString stringWithFormat:@"%i Folders", [dataModel count]];
	
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	reloadTimeLabel.text = [NSString stringWithFormat:@"last reload: %@", [formatter stringFromDate:[[SavedSettings sharedInstance] rootFoldersReloadTime]]];
	[formatter release];
	
}

-(void)addCount
{	
	isCountShowing = YES;
	
	headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 126)] autorelease];
	headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	headerView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];
	
	CGRect sepFrame = CGRectMake(0, 0, headerView.bounds.size.width, 2);
	SeparaterView *sepView = [[SeparaterView alloc] initWithFrame:sepFrame];
	[headerView addSubview:sepView];
	[sepView release];
	
	blockerButton = [UIButton buttonWithType:UIButtonTypeCustom];
	blockerButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	blockerButton.frame = headerView.frame;
	[headerView addSubview:blockerButton];
	
	countLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, 320, 30)];
	countLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	countLabel.backgroundColor = [UIColor clearColor];
	countLabel.textColor = [UIColor colorWithRed:156.0/255.0 green:161.0/255.0 blue:168.0/255.0 alpha:1];
	countLabel.textAlignment = UITextAlignmentCenter;
	countLabel.font = [UIFont boldSystemFontOfSize:30];
	[headerView addSubview:countLabel];
	[countLabel release];
	
	reloadTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 36, 320, 12)];
	reloadTimeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	reloadTimeLabel.backgroundColor = [UIColor clearColor];
	reloadTimeLabel.textColor = [UIColor colorWithRed:176.0/255.0 green:181.0/255.0 blue:188.0/255.0 alpha:1];
	reloadTimeLabel.textAlignment = UITextAlignmentCenter;
	reloadTimeLabel.font = [UIFont systemFontOfSize:11];
	[headerView addSubview:reloadTimeLabel];
	[reloadTimeLabel release];	
	
	searchBar = [[UISearchBar  alloc] initWithFrame:CGRectMake(0, 86, 320, 40)];
	searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	searchBar.delegate = self;
	searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	searchBar.placeholder = @"Folder name";
	[headerView addSubview:searchBar];
	[searchBar release];
	
	self.dropdown = [[FolderDropdownControl alloc] initWithFrame:CGRectMake(50, 53, 220, 30)];
	dropdown.delegate = self;
	NSDictionary *dropdownFolders = [SUSRootFoldersDAO folderDropdownFolders];
	if (dropdownFolders != nil)
	{
		dropdown.folders = dropdownFolders;
	}
	else
	{
		dropdown.folders = [NSDictionary dictionaryWithObject:@"All Folders" forKey:[NSNumber numberWithInt:-1]];
	}
	[dropdown selectFolderWithId:[dataModel selectedFolderId]];
	
	[headerView addSubview:dropdown];
	[dropdown release];
	
	[self updateCount];
	
	self.tableView.tableHeaderView = headerView;
}

-(void)loadData:(NSNumber *)folderId 
{
	[dropdown updateFolders];
	
	viewObjects.isArtistsLoading = YES;
	
	allArtistsLoadingScreen = [[LoadingScreen alloc] initOnView:self.view.superview withMessage:[NSArray arrayWithObjects:@"Processing Folders", @"", @"", @"", nil]  blockInput:YES mainWindow:NO];
	
	dataModel.selectedFolderId = folderId;
	[dataModel startLoad];
}

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{	
	viewObjects.isArtistsLoading = NO;
	
	// Hide the loading screen
	[allArtistsLoadingScreen hide]; 
	[allArtistsLoadingScreen release]; allArtistsLoadingScreen = nil;
	
	[self dataSourceDidFinishLoadingNewData];
	
	// Inform the user that the connection failed.
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error loading the artist list.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	[alert release];
}

- (void)loadingFinished:(SUSLoader*)theLoader
{	
    //DLog(@"loadingFinished called");
	if (isCountShowing)
		[self updateCount];
	else
		[self addCount];		
	
	[self.tableView reloadData];
	self.tableView.backgroundColor = [UIColor clearColor];
	
	viewObjects.isArtistsLoading = NO;
	
	// Hide the loading screen
	[allArtistsLoadingScreen hide]; 
	[allArtistsLoadingScreen release]; allArtistsLoadingScreen = nil;
	
	[self dataSourceDidFinishLoadingNewData];
}

#pragma mark - Folder Dropdown Delegate

- (void)folderDropdownMoveViewsY:(float)y
{
	[self.tableView beginUpdates];
	self.tableView.tableHeaderView.height += y;
	searchBar.y += y;
	blockerButton.frame = self.tableView.tableHeaderView.frame;
	
	for (UIView *subView in self.tableView.subviews)
	{
		if (subView != self.tableView.tableHeaderView && subView != refreshHeaderView)
			subView.y += y;
	}
	
	/*for (UITableViewCell *cell in self.tableView.visibleCells)
	{
		cell.y += y;
	}*/
	
	self.tableView.tableHeaderView = self.tableView.tableHeaderView;
	[self.tableView endUpdates];
}

- (void)folderDropdownViewsFinishedMoving
{
	self.tableView.tableHeaderView = self.tableView.tableHeaderView;
	[self.tableView setNeedsLayout];
}

- (void)folderDropdownSelectFolder:(NSNumber *)folderId
{
	// Save the default
	[SavedSettings sharedInstance].rootFoldersSelectedFolderId = folderId;
	
	// Reload the data
	dataModel.selectedFolderId = folderId;
	isSearching = NO;
	if ([dataModel isRootFolderIdCached])
	{
		[self.tableView reloadData];
		[self updateCount];
	}
	else
	{
		[self loadData:folderId];
	}
}

- (void)serverSwitched
{
	[self createDataModel];
	[self folderDropdownSelectFolder:[NSNumber numberWithInteger:-1]];
}

#pragma mark - Button handling methods


- (void)doneSearching_Clicked:(id)sender 
{
	[self updateCount];
	
	searchBar.text = @"";
	[searchBar resignFirstResponder];
	
	letUserSelectRow = YES;
	isSearching = NO;
	self.navigationItem.leftBarButtonItem = nil;
	self.tableView.scrollEnabled = YES;
	
	[searchOverlayView.view removeFromSuperview];
	[searchOverlayView release];
	searchOverlayView = nil;
	
	[dataModel clearSearchTable];
	
	[self.tableView reloadData];
	
	[self.tableView setContentOffset:CGPointMake(0, 86) animated:YES];
}

- (void) reloadAction:(id)sender
{
	if (![SUSAllSongsLoader isLoading])
	{
		[self loadData:[[SavedSettings sharedInstance] rootFoldersSelectedFolderId]];
	}
	else
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Please Wait" message:@"You cannot reload the Artists tab while the Albums or Songs tabs are loading" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		[alert release];
	}
}


- (void) settingsAction:(id)sender 
{
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
	[serverListViewController release];
}


- (IBAction)nowPlayingAction:(id)sender
{
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
	[streamingPlayerViewController release];
}


#pragma mark -
#pragma mark SearchBar


- (void) searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar 
{
	if (isSearching)
		return;
	
	// Remove the index bar
	isSearching = YES;
	[dataModel clearSearchTable];
	[self.tableView reloadData];
	
	[self.tableView.tableHeaderView retain];

	[dropdown closeDropdownFast];
	[self.tableView setContentOffset:CGPointMake(0, 86) animated:YES];
	
	if ([theSearchBar.text length] == 0)
	{
		//Add the overlay view.
		if(searchOverlayView == nil)
			searchOverlayView = [[SearchOverlayViewController alloc] initWithNibName:@"SearchOverlayViewController" bundle:[NSBundle mainBundle]];
		//CGFloat y = self.tableView.contentOffset.y - searchBar.frame.origin.y + searchBar.frame.size.height;
		CGFloat width = self.view.frame.size.width;
		CGFloat height = self.view.frame.size.height;
		//CGRect frame = CGRectMake(0, y, width, height);
		CGRect frame = CGRectMake(0, 40, width, height);
		searchOverlayView.view.frame = frame;
		[self.view.superview addSubview:searchOverlayView.view];
		
		letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
	}
	
	//Add the done button.
	self.navigationItem.leftBarButtonItem = nil;
	self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneSearching_Clicked:)] autorelease];
}


- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText
{
	if([searchText length] > 0) 
	{
		[searchOverlayView.view removeFromSuperview];
		letUserSelectRow = YES;
		self.tableView.scrollEnabled = YES;
		
		[dataModel searchForFolderName:searchBar.text];
		
		[self.tableView reloadData];
	}
	else 
	{		
		//Add the overlay view.
		if(searchOverlayView == nil)
			searchOverlayView = [[SearchOverlayViewController alloc] initWithNibName:@"SearchOverlayViewController" bundle:[NSBundle mainBundle]];
		CGFloat width = self.view.frame.size.width;
		CGFloat height = self.view.frame.size.height;
		CGRect frame = CGRectMake(0, 40, width, height);
		searchOverlayView.view.frame = frame;
		[self.view.superview addSubview:searchOverlayView.view];
		
		letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
		
		[dataModel clearSearchTable];
		
		[self.tableView reloadData];
		
		[self.tableView setContentOffset:CGPointMake(0, 86) animated:NO];
	}
}

- (void) searchBarSearchButtonClicked:(UISearchBar *)theSearchBar 
{
	//[self searchTableView];
	[searchBar resignFirstResponder];
}


#pragma mark TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{	
	if (isSearching)
	{
		return 1;
	}
	else
	{
		NSUInteger count = [[dataModel indexNames] count];
		return count;
	}
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (isSearching)
	{
		NSUInteger count = dataModel.searchCount;
		return count;
	}
	else 
	{
		if ([[dataModel indexCounts] count] > section)
		{
			NSUInteger count = [[[dataModel indexCounts] objectAtIndexSafe:section] intValue];
			return count;
		}
		
		return 0;
	}
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{	
	static NSString *CellIdentifier = @"Cell";
	ArtistUITableViewCell *cell = [[[ArtistUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
			
	Artist *anArtist = nil;
	if(isSearching)
	{
		anArtist = [dataModel artistForPositionInSearch:(indexPath.row + 1)];
	}
	else
	{
		if ([[dataModel indexPositions] count] > indexPath.section)
		{
			//DLog(@"indexPositions: %@", [dataModel indexPositions]);
			NSUInteger sectionStartIndex = [[[dataModel indexPositions] objectAtIndexSafe:indexPath.section] intValue];
			anArtist = [dataModel artistForPosition:(sectionStartIndex + indexPath.row)];
		}
	}
	cell.myArtist = anArtist;
	
	[cell.artistNameLabel setText:anArtist.name];
	cell.backgroundView = [viewObjects createCellBackground:indexPath.row];
		
	return cell;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	
	if(isSearching)
		return @"";
	
	if ([[dataModel indexNames] count] == 0)
		return @"";
	
	NSString *title = [[dataModel indexNames] objectAtIndexSafe:section];

	return title;
}


// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView 
{
	if(isSearching)
		return nil;
	
	NSMutableArray *titles = [NSMutableArray arrayWithCapacity:0];
	[titles addObject:@"{search}"];
	[titles addObjectsFromArray:[dataModel indexNames]];
		
	return titles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	if(isSearching)
		return -1;
	
	if (index == 0) 
	{
		if (dropdown.folders == nil || [dropdown.folders count] == 2)
			[self.tableView setContentOffset:CGPointMake(0, 86) animated:NO];
		else
			[self.tableView setContentOffset:CGPointMake(0, 50) animated:NO];
		
		return -1;
	}
	
	return index - 1;
}


- (NSIndexPath *)tableView :(UITableView *)theTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	DLog(@"will indexPath.row: %i", indexPath.row);
	if(letUserSelectRow)
		return indexPath;
	else
		return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (viewObjects.isCellEnabled)
	{
		DLog(@"did indexPath.row: %i", indexPath.row);
		Artist *anArtist = nil;
		if(isSearching)
		{
			anArtist = [dataModel artistForPositionInSearch:(indexPath.row + 1)];
		}
		else 
		{	
			if ([[dataModel indexPositions] count] > indexPath.section)
			{
				NSUInteger sectionStartIndex = [[[dataModel indexPositions] objectAtIndexSafe:indexPath.section] intValue];
				anArtist = [dataModel artistForPosition:(sectionStartIndex + indexPath.row)];
			}
		}
		AlbumViewController* albumViewController = [[AlbumViewController alloc] initWithArtist:anArtist orAlbum:nil];
		[self pushViewController:albumViewController];
		[albumViewController release];
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

#pragma mark -
#pragma mark Pull to refresh methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{	
	if (scrollView.isDragging) 
	{
		if (refreshHeaderView.state == EGOOPullRefreshPulling && scrollView.contentOffset.y > -65.0f && scrollView.contentOffset.y < 0.0f && !_reloading) 
		{
			[refreshHeaderView setState:EGOOPullRefreshNormal];
		} 
		else if (refreshHeaderView.state == EGOOPullRefreshNormal && scrollView.contentOffset.y < -65.0f && !_reloading) 
		{
			[refreshHeaderView setState:EGOOPullRefreshPulling];
		}
	}
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	if (scrollView.contentOffset.y <= - 65.0f && !_reloading) 
	{
		_reloading = YES;
		[self loadData:[[SavedSettings sharedInstance] rootFoldersSelectedFolderId]];
		[refreshHeaderView setState:EGOOPullRefreshLoading];
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.2];
		self.tableView.contentInset = UIEdgeInsetsMake(60.0f, 0.0f, 0.0f, 0.0f);
		[UIView commitAnimations];
	}
}

- (void)dataSourceDidFinishLoadingNewData
{
	_reloading = NO;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[self.tableView setContentInset:UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f)];
	[UIView commitAnimations];
	
	[refreshHeaderView setState:EGOOPullRefreshNormal];
}

@end

