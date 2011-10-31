//
//  LyricsViewController.m
//  iSub
//
//  Created by Ben Baron on 7/11/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "LyricsViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "Song.h"
#import "SUSLyricsDAO.h"

@implementation LyricsViewController

@synthesize textView, dataModel;

#pragma mark - Lifecycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil 
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) 
	{		
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		viewObjects = [ViewObjectsSingleton sharedInstance];
		musicControls = [MusicSingleton sharedInstance];
		databaseControls = [DatabaseSingleton sharedInstance];
        
        dataModel = [[SUSLyricsDAO alloc] initWithDelegate:self];
		
        // Custom initialization
		self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 300)];
		self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		
		textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 320, 300)];
		textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		textView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
		textView.textColor = [UIColor whiteColor];
		textView.font = [UIFont systemFontOfSize:16.5];
		textView.editable = NO;
        
        NSString *lyrics = [dataModel lyricsForArtist:musicControls.currentSongObject.artist andTitle:musicControls.currentSongObject.title];
                
		if (lyrics)
		{
			textView.text = lyrics;
		}
		else
		{
			if (viewObjects.isOfflineMode)
			{
				textView.text = @"\n\nNo lyrics found";
			}
			else
			{
				textView.text = @"\n\nLoading Lyrics...";
			}
		}
		[self.view addSubview:textView];
		[textView release];
		
		UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 45)];
		titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		titleLabel.backgroundColor = [UIColor clearColor];
		titleLabel.textColor = [UIColor whiteColor];
		titleLabel.font = [UIFont boldSystemFontOfSize:32];
		titleLabel.textAlignment = UITextAlignmentCenter;
		titleLabel.text = @"Lyrics";
		[textView addSubview:titleLabel];
		[titleLabel release];		
		
		[self viewDidLoad];
    }
    return self;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLyricsLabel) name:@"lyricsDoneLoading" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidUnload) name:@"hideSongInfoFast" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidUnload) name:@"hideSongInfo" object:nil];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"lyricsDoneLoading" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideSongInfoFast" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideSongInfo" object:nil];
}

- (void)viewDidUnload 
{
    [super viewDidUnload];
}

- (void)dealloc 
{
	[textView release]; textView = nil;
    [super dealloc];
    
}

- (void) updateLyricsLabel
{	
	[textView performSelectorOnMainThread:@selector(setText:) withObject:musicControls.currentSongLyrics waitUntilDone:NO];
}

#pragma mark - SUSLoader delegate

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{
    textView.text = @"\n\nNo lyrics found";
}

- (void)loadingFinished:(SUSLoader*)theLoader
{
    textView.text = [dataModel lyricsForArtist:musicControls.currentSongObject.artist andTitle:musicControls.currentSongObject.title];
}

@end
