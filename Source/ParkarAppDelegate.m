//
//  WharCarAppDelegate.m
//  WharCar
//
//  Created by P. Mark Anderson on 5/7/10.
//  Copyright Spot Metrix, Inc 2010. All rights reserved.
//

#import "ParkarAppDelegate.h"
#import "ParkarViewController.h"
#import "Constants.h"

@implementation ParkarAppDelegate

@synthesize window;
@synthesize tabBarController;

- (void) dealloc 
{
    RELEASE(tabBarController);
    RELEASE(window);
    [super dealloc];
}

- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions 
{    
    [application setStatusBarHidden:NO];
    [window addSubview:tabBarController.view];
    [window makeKeyAndVisible];
	
	return YES;
}

// called when a new view is selected by the user (but not programatically)
- (void) tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
    // TODO: if not Map item, suspend 3DAR
}



@end
