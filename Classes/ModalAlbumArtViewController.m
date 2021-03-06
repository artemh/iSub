//
//  ModalAlbumArtViewController.m
//  iSub
//
//  Created by bbaron on 11/13/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ModalAlbumArtViewController.h"
 
@implementation ModalAlbumArtViewController
@synthesize albumArt, artistLabel, albumLabel, myAlbum, numberOfTracks, albumLength, durationLabel, trackCountLabel, labelHolderView, albumArtReflection;

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	if (!IS_IPAD())
	{
		[UIView beginAnimations:@"rotate" context:nil];
		//[UIView setAnimationDelegate:self];
		//[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:duration];
		
		if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
		{
			albumArt.width = 480;
			albumArt.height = 320;
			labelHolderView.alpha = 0.0;
			
		}
		else
		{
			albumArt.width = 320;
			albumArt.height = 320;
			labelHolderView.alpha = 1.0;
		}
		
		[UIView commitAnimations];
		
		[[UIApplication sharedApplication] setStatusBarHidden:UIInterfaceOrientationIsLandscape(toInterfaceOrientation) 
												withAnimation:UIStatusBarAnimationSlide];
	}
}

- (id)initWithAlbum:(ISMSAlbum *)theAlbum numberOfTracks:(NSUInteger)tracks albumLength:(NSUInteger)length
{
	if ((self = [super initWithNibName:@"ModalAlbumArtViewController" bundle:nil]))
	{
		if ([self respondsToSelector:@selector(setModalPresentationStyle:)])
			self.modalPresentationStyle = UIModalPresentationFormSheet;
		
		myAlbum = [theAlbum copy];
		numberOfTracks = tracks;
		albumLength = length;
	}
	
	return self;
}

- (void)viewDidLoad
{	
	if (IS_IPAD())
	{
		// Fix album art size for iPad
		albumArt.width = 540;
		albumArt.height = 540;
		albumArtReflection.y = 540;
		albumArtReflection.width = 540;
		labelHolderView.height = 125;
		labelHolderView.y = 500;
	}
	
	albumArt.isLarge = YES;
	albumArt.delegate = self;
	
	//[UIApplication setStatusBarHidden:YES withAnimation:YES];
	
	artistLabel.text = myAlbum.artistName;
	albumLabel.text = myAlbum.title;
	durationLabel.text = [NSString formatTime:albumLength];
	trackCountLabel.text = [NSString stringWithFormat:@"%i Tracks", numberOfTracks];
	if (numberOfTracks == 1)
		trackCountLabel.text = [NSString stringWithFormat:@"%i Track", numberOfTracks];
	
	albumArt.coverArtId = self.myAlbum.coverArtId;
	
	albumArtReflection.image = [albumArt reflectedImageWithHeight:albumArtReflection.height];
	
	if (!IS_IPAD())
	{
		if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
		{
			[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
			albumArt.width = 480;
		}
		else
		{
			[[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
		}
	}
}

- (BOOL)shouldAutorotate
{
    return [self shouldAutorotateToInterfaceOrientation:[UIDevice currentDevice].orientation];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	if (settingsS.isRotationLockEnabled && interfaceOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    // Overriden to allow any orientation.
    return YES;
}

- (IBAction)dismiss:(id)sender
{
	if (!IS_IPAD())
		[[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
	
	[self dismissModalViewControllerAnimated:YES];
}

- (void)didReceiveMemoryWarning 
{
    [super didReceiveMemoryWarning];
}


- (void)asyncImageViewFinishedLoading:(AsynchronousImageView *)asyncImageView
{
	albumArtReflection.image = [albumArt reflectedImageWithHeight:albumArtReflection.height];
}

@end
