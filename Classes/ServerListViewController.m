//
//  ServerListViewController.m
//  iSub
//
//  Created by Ben Baron on 3/31/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ServerListViewController.h"
#import "SubsonicServerEditViewController.h"
#import "iSubAppDelegate.h"
#import "MusicSingleton.h"
#import "ViewObjectsSingleton.h"
#import "DatabaseSingleton.h"
#import "SettingsTabViewController.h"
#import "HelpTabViewController.h"
#import "FoldersViewController.h"
#import "Server.h"
#import "ServerTypeViewController.h"
#import "UbuntuServerEditViewController.h"
#import "UIView+Tools.h"
#import "CustomUIAlertView.h"
#import "Reachability.h"
#import "SavedSettings.h"
#import "AudioEngine.h"
#import "SUSAllSongsLoader.h"
#import "ISMSStreamManager.h"
#import "NSArray+Additions.h"
#import "NSNotificationCenter+MainThread.h"

@implementation ServerListViewController

@synthesize theNewRedirectionUrl;

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	viewObjectsS.isSettingsShowing = YES;
}

/* DOESN'T GET CALLED, setting isSettingShowing to NO in NewHomeViewController viewWillAppear instead
- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	viewObjectsS.isSettingsShowing = NO;
}*/

- (void)viewDidLoad 
{
    [super viewDidLoad];

	
	theNewRedirectionUrl = nil;
	
	self.tableView.allowsSelectionDuringEditing = YES;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:@"reloadServerList" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showSaveButton) name:@"showSaveButton" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(switchServer:) name:@"switchServer" object:nil];
	
	//viewObjectsS.tempServerList = [[NSMutableArray arrayWithArray:viewObjectsS.serverList] retain];
	//DLog(@"tempServerList: %@", viewObjectsS.tempServerList);
	
	self.title = @"Servers";
	if(self != [[self.navigationController viewControllers] objectAtIndexSafe:0])
		self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleBordered target:self action:@selector(saveAction:)] autorelease];
	self.navigationItem.rightBarButtonItem = self.editButtonItem;
	
	if (settingsS.serverList == nil || [settingsS.serverList count] == 0)
		[self addAction:nil];
	
	// Setup segmented control in the header view
	headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 40)] autorelease];
	headerView.backgroundColor = [UIColor colorWithWhite:.3 alpha:1];
	
	segmentedControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Servers", @"Settings", @"Help", nil]];
	segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[segmentedControl addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];
	segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
	segmentedControl.frame = CGRectMake(5, 2, 310, 36);
	segmentedControl.tintColor = [UIColor colorWithWhite:.57 alpha:1];
	segmentedControl.selectedSegmentIndex = 0;
	[headerView addSubview:segmentedControl];
	
	self.tableView.tableHeaderView = headerView;
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	else
	{
		// Add the table fade
		UIImageView *fadeTop = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-top.png"]];
		fadeTop.frame =CGRectMake(0, -10, self.tableView.bounds.size.width, 10);
		fadeTop.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self.tableView addSubview:fadeTop];
		[fadeTop release];
		
		UIImageView *fadeBottom = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
		fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
		fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.tableView.tableFooterView = fadeBottom;
	}
}


- (void)reloadTable
{
	[self.tableView reloadData];
}


- (void)showSaveButton
{
	if(!isEditing)
	{
		if(self == [[self.navigationController viewControllers] firstObjectSafe])
			self.navigationItem.leftBarButtonItem = nil;
		else
			self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleBordered target:self action:@selector(saveAction:)] autorelease];
		
	}
}


- (void)segmentAction:(id)sender
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		self.title = @"Servers";
		
		self.tableView.scrollEnabled = YES;
		self.navigationItem.rightBarButtonItem = self.editButtonItem;
		
		UIImageView *fadeBottom = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
		fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
		fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.tableView.tableFooterView = fadeBottom;
		
		[self.tableView reloadData];
	}
	else if (segmentedControl.selectedSegmentIndex == 1)
	{
		self.title = @"Settings";
		
		self.tableView.scrollEnabled = YES;
		[self setEditing:NO animated:NO];
		self.navigationItem.rightBarButtonItem = nil;
		SettingsTabViewController *settingsTabViewController = [[SettingsTabViewController alloc] initWithNibName:@"SettingsTabViewController" bundle:nil];
		settingsTabViewController.parentController = self;
		self.tableView.tableFooterView = settingsTabViewController.view;
		//[settingsTabViewController release];
		[self.tableView reloadData];
	}
	else if (segmentedControl.selectedSegmentIndex == 2)
	{
		self.title = @"Help";
		
		self.tableView.scrollEnabled = NO;
		[self setEditing:NO animated:NO];
		self.navigationItem.rightBarButtonItem = nil;
		HelpTabViewController *helpTabViewController = [[HelpTabViewController alloc] initWithNibName:@"HelpTabViewController" bundle:nil];
		if (IS_IPAD())
		{
			helpTabViewController.view.frame = self.view.bounds;
			helpTabViewController.view.height -= 40.;
		}
		self.tableView.tableFooterView = helpTabViewController.view;
		[helpTabViewController release];
		[self.tableView reloadData];
	}
}


- (void)setEditing:(BOOL)editing animated:(BOOL)animate
{
    [super setEditing:editing animated:animate];
    if(editing)
    {
		isEditing = YES;
		self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addAction:)] autorelease];
    }
    else
    {
		isEditing = NO;
		[self showSaveButton];
    }
}

- (void)addAction:(id)sender
{
	viewObjectsS.serverToEdit = nil;
	
	ServerTypeViewController *serverTypeViewController = [[ServerTypeViewController alloc] initWithNibName:@"ServerTypeViewController" bundle:nil];
	if ([serverTypeViewController respondsToSelector:@selector(setModalPresentationStyle:)])
		serverTypeViewController.modalPresentationStyle = UIModalPresentationFormSheet;
	if (IS_IPAD())
		[appDelegateS.ipadRootViewController presentModalViewController:serverTypeViewController animated:YES];
	else
		[self presentModalViewController:serverTypeViewController animated:YES];
	[serverTypeViewController release];
}

- (void)saveAction:(id)sender
{
	[self.navigationController popToRootViewControllerAnimated:YES];
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)showServerEditScreen
{
	if (viewObjectsS.serverToEdit.type == UBUNTU_ONE)
	{
		UbuntuServerEditViewController *ubuntuServerEditViewController = [[UbuntuServerEditViewController alloc] initWithNibName:@"UbuntuServerEditViewController" bundle:nil];
		if ([ubuntuServerEditViewController respondsToSelector:@selector(setModalPresentationStyle:)])
			ubuntuServerEditViewController.modalPresentationStyle = UIModalPresentationFormSheet;
		[self presentModalViewController:ubuntuServerEditViewController animated:YES];
		[ubuntuServerEditViewController release];
	}
	else // Default to Subsonic
	{
		SubsonicServerEditViewController *subsonicServerEditViewController = [[SubsonicServerEditViewController alloc] initWithNibName:@"SubsonicServerEditViewController" bundle:nil];
		if ([subsonicServerEditViewController respondsToSelector:@selector(setModalPresentationStyle:)])
			subsonicServerEditViewController.modalPresentationStyle = UIModalPresentationFormSheet;
		[self presentModalViewController:subsonicServerEditViewController animated:YES];
		[subsonicServerEditViewController release];
	}
}

- (void)switchServer:(NSNotification*)notification 
{	
	if (notification.userInfo)
	{
		self.theNewRedirectionUrl = [notification.userInfo objectForKey:@"theNewRedirectUrl"];
	}
	
	// Save the plist values
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:viewObjectsS.serverToEdit.url forKey:@"url"];
	[defaults setObject:viewObjectsS.serverToEdit.username forKey:@"username"];
	[defaults setObject:viewObjectsS.serverToEdit.password forKey:@"password"];
	[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:settingsS.serverList] forKey:@"servers"];
	[defaults synchronize];
	
	// Update the variables
	settingsS.urlString = [NSString stringWithString:viewObjectsS.serverToEdit.url];
	settingsS.username = [NSString stringWithString:viewObjectsS.serverToEdit.username];
	settingsS.password = [NSString stringWithString:viewObjectsS.serverToEdit.password];
    settingsS.redirectUrlString = self.theNewRedirectionUrl;
	
	DLog(@" settingsS.urlString: %@   settingsS.redirectUrlString: %@", settingsS.urlString, settingsS.redirectUrlString);
		
	[self retain];
	if(self == [[self.navigationController viewControllers] objectAtIndexSafe:0] && !IS_IPAD())
	{
		[self.navigationController.view removeFromSuperview];
	}
	else
	{
		[self.navigationController popToRootViewControllerAnimated:YES];
		
		if ([appDelegateS.wifiReach currentReachabilityStatus] == NotReachable)
			return;
		
		// Cancel any caching
		[streamManagerS removeAllStreams];
		
		// Cancel any tab loads
		if ([SUSAllSongsLoader isLoading])
		{
			DLog(@"detected all songs loading");
			viewObjectsS.cancelLoading = YES;
		}
		
		while (viewObjectsS.cancelLoading == YES)
		{
			DLog(@"waiting for the load to cancel before continuing");
		}
		
		// Stop any playing song and remove old tab bar controller from window
		[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:@"recover"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[audioEngineS stop];
		 settingsS.isJukeboxEnabled = NO;
		
		if (!IS_IPAD())
			[appDelegateS.mainTabBarController.view removeFromSuperview];
		
		// Reset the databases
		[databaseS closeAllDatabases];
		
		[databaseS initDatabases];
				
		if (viewObjectsS.isOfflineMode)
		{
			viewObjectsS.isOfflineMode = NO;
			
			if (!IS_IPAD())
			{
				[appDelegateS.offlineTabBarController.view removeFromSuperview];
				[viewObjectsS orderMainTabBarController];
			}
		}
		
		// Reset the tabs
		if (!IS_IPAD())
			[appDelegateS.rootViewController.navigationController popToRootViewControllerAnimated:NO];
				
		// Add the tab bar controller back to the window
		if (!IS_IPAD())
			[appDelegateS.window addSubview:[appDelegateS.mainTabBarController view]];
		
		appDelegateS.window.backgroundColor = viewObjectsS.windowColor;
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ServerSwitched];
	}
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	if (segmentedControl.selectedSegmentIndex == 0)
		return [settingsS.serverList count];
	else
		return 0;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *cellIdentifier = @"ServerListCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) 
	{
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
	
	Server *aServer = [settingsS.serverList objectAtIndexSafe:indexPath.row];
	
	// Set up the cell...
	UILabel *serverNameLabel = [[UILabel alloc] init];
	serverNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	serverNameLabel.backgroundColor = [UIColor clearColor];
	serverNameLabel.textAlignment = UITextAlignmentLeft; // default
	serverNameLabel.font = [UIFont boldSystemFontOfSize:20];
	[serverNameLabel setText:aServer.url];
	[cell.contentView addSubview:serverNameLabel];
	[serverNameLabel release];
	
	UILabel *detailsLabel = [[UILabel alloc] init];
	detailsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	detailsLabel.backgroundColor = [UIColor clearColor];
	detailsLabel.textAlignment = UITextAlignmentLeft; // default
	detailsLabel.font = [UIFont systemFontOfSize:15];
	[detailsLabel setText:[NSString stringWithFormat:@"username: %@", aServer.username]];
	[cell.contentView addSubview:detailsLabel];
	[detailsLabel release];
	
	UIImage *typeImage = nil;
	if ([aServer.type isEqualToString:SUBSONIC])
		typeImage = [UIImage imageNamed:@"server-subsonic.png"];
	else if ([aServer.type isEqualToString:UBUNTU_ONE])
		typeImage = [UIImage imageNamed:@"server-ubuntu.png"];

	UIImageView *serverType = [[UIImageView alloc] initWithImage:typeImage];
	serverType.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[cell.contentView addSubview:serverType];
	[serverType release];
	
	if([ settingsS.urlString isEqualToString:aServer.url] && 
	   [ settingsS.username isEqualToString:aServer.username] &&
	   [ settingsS.password isEqualToString:aServer.password])
	{
		UIImageView *currentServerMarker = [[UIImageView alloc] init];
		currentServerMarker.image = [UIImage imageNamed:@"current-server.png"];
		[cell.contentView addSubview:currentServerMarker];
		[currentServerMarker release];
		
		currentServerMarker.frame = CGRectMake(3, 12, 26, 26);
		serverNameLabel.frame = CGRectMake(35, 0, 236, 25);
		detailsLabel.frame = CGRectMake(35, 27, 236, 18);
	}
	else 
	{
		serverNameLabel.frame = CGRectMake(5, 0, 266, 25);
		detailsLabel.frame = CGRectMake(5, 27, 266, 18);
	}
	serverType.frame = CGRectMake(271, 3, 44, 44);
	
	cell.backgroundView = [[[UIView alloc] init] autorelease];
	if(indexPath.row % 2 == 0)
		cell.backgroundView.backgroundColor = [viewObjectsS lightNormal];
	else
		cell.backgroundView.backgroundColor = [viewObjectsS darkNormal];
	
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
	viewObjectsS.serverToEdit = [ settingsS.serverList objectAtIndexSafe:indexPath.row];
	DLog(@"viewObjectsS.serverToEdit.url: %@", viewObjectsS.serverToEdit.url);

	if (isEditing)
	{
		[self showServerEditScreen];
	}
	else
	{
		self.theNewRedirectionUrl = nil;
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Checking Server"];
		SUSServerChecker *checker = [[SUSServerChecker alloc] initWithDelegate:self];
		[checker checkServerUrlString:viewObjectsS.serverToEdit.url username:viewObjectsS.serverToEdit.username password:viewObjectsS.serverToEdit.password];
	}
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}


- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return YES;
}


- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath 
{
	NSArray *server = [[ settingsS.serverList objectAtIndexSafe:fromIndexPath.row] retain];
	[ settingsS.serverList removeObjectAtIndex:fromIndexPath.row];
	[ settingsS.serverList insertObject:server atIndex:toIndexPath.row];
	[server release];
	[[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject: settingsS.serverList] forKey:@"servers"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[self.tableView reloadData];
}


// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) 
	{
		// Alert user to select new default server if they deleting the default
		if ([ settingsS.urlString isEqualToString:[(Server *)[ settingsS.serverList objectAtIndexSafe:indexPath.row] url]])
		{
			CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Make sure to select a new server" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
			alert.tag = 4;
			[alert show];
			[alert release];
		}
		
        // Delete the row from the data source
        [settingsS.serverList removeObjectAtIndex:indexPath.row];
		
		@try
		{
			[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
		}
		@catch (NSException *exception) 
		{
			DLog(@"Exception: %@ - %@", exception.name, exception.reason);
		}
		
		[self.tableView reloadData];
		
		// Save the plist values
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject: settingsS.serverList] forKey:@"servers"];
		[defaults synchronize];
    }   
}


- (void)dealloc 
{
	[theNewRedirectionUrl release]; theNewRedirectionUrl = nil;
    [super dealloc];
}

- (void)SUSServerURLCheckFailed:(SUSServerChecker *)checker withError:(NSError *)error
{	
	UIAlertView *alert = nil;
	if (error.code == ISMSErrorCode_IncorrectCredentials)
	{
		alert = [[UIAlertView alloc] initWithTitle:@"Server Unavailable" message:[NSString stringWithFormat:@"Either your username or password is incorrect\n\n☆☆ Tap the gear in the top left and choose a server to return to online mode. ☆☆\n\nError code %i:\n%@", [error code], [error localizedDescription]] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	}
	else
	{
		alert = [[UIAlertView alloc] initWithTitle:@"Server Unavailable" message:[NSString stringWithFormat:@"Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\n☆☆ Tap the gear in the top left and choose a server to return to online mode. ☆☆\n\nError code %i:\n%@", [error code], [error localizedDescription]] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	}
	alert.tag = 3;
	[alert show];
	[alert release];	
    
    [checker release]; checker = nil;
	    
    DLog(@"server verification failed, hiding loading screen");
    [viewObjectsS hideLoadingScreen];
}

- (void)SUSServerURLCheckPassed:(SUSServerChecker *)checker
{
	 settingsS.isNewSearchAPI = checker.isNewSearchAPI;
    
    [checker release]; checker = nil;
	
	 settingsS.urlString = [NSString stringWithString:viewObjectsS.serverToEdit.url];
	 settingsS.username = [NSString stringWithString:viewObjectsS.serverToEdit.username];
	 settingsS.password = [NSString stringWithString:viewObjectsS.serverToEdit.password];
    settingsS.redirectUrlString = self.theNewRedirectionUrl;
	
	[self switchServer:nil];
    
    DLog(@"server verification passed, hiding loading screen");
    [viewObjectsS hideLoadingScreen];
}

- (void)SUSServerURLCheckRedirected:(SUSServerChecker *)checker redirectUrl:(NSURL *)url
{
    self.theNewRedirectionUrl = [NSString stringWithFormat:@"%@://%@:%@", url.scheme, url.host, url.port];
}

@end

