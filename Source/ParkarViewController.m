//
//  WharCarViewController.m
//  WharCar
//
//  Created by P. Mark Anderson on 5/7/10.
//  Copyright Spot Metrix, Inc 2010. All rights reserved.
//

#import "ParkarViewController.h"
#import "Constants.h"
#import "RoundedLabelMarkerView.h"
#import "PointOfInterest.h"

#define BTN_TITLE_SET_SPOT @"Drop Pin"
#define BTN_TITLE_RESET_SPOT @"Reset"

#define POINTER_UPDATE_SEC 0.75
#define HEADING_DELTA_THRESHOLD 5

@implementation ParkarViewController

@synthesize screen1;
@synthesize screen2;
@synthesize crosshairs;
@synthesize parkButton;
@synthesize parkingSpot;
@synthesize pointer;
@synthesize compass;

- (void)dealloc 
{
    RELEASE(screen1);
    RELEASE(screen2);
    RELEASE(crosshairs);
    RELEASE(parkButton);
    RELEASE(parkingSpot);
    RELEASE(pointer);
    RELEASE(compass);
    RELEASE(hudTimer);
    [super dealloc];
}

- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil 
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) 
    {
        lastHeading = 0.0;
    }
    return self;
}

- (SM3DAR_PointOfInterest*) addPOI:(NSString*)title subtitle:(NSString*)subtitle latitude:(CLLocationDegrees)lat longitude:(CLLocationDegrees)lon  canReceiveFocus:(BOOL)canReceiveFocus 
{
    SM3DAR_Controller *sm3dar = [SM3DAR_Controller sharedController];
    NSDictionary *poiProperties = [NSDictionary dictionaryWithObjectsAndKeys: 
                                   title, @"title",
                                   subtitle, @"subtitle",
                                   @"RoundedLabelMarkerView", @"view_class_name",
                                   [NSNumber numberWithDouble:lat], @"latitude",
                                   [NSNumber numberWithDouble:lon], @"longitude",
                                   0, @"altitude",
                                   nil];
    
    SM3DAR_PointOfInterest *poi = [[sm3dar initPointOfInterest:poiProperties] autorelease];    
    poi.canReceiveFocus = canReceiveFocus;
    [sm3dar addPointOfInterest:poi];
    return poi;
}

- (void) zoomMapIn
{
    SM3DAR_Controller *sm3dar = [SM3DAR_Controller sharedController];
    if (parkingSpot)
    {
        [sm3dar zoomMapToFit];
    }
    else
    {
        MKCoordinateRegion region = {{0.0f, 0.0f}, {0.0f, 0.0f}};
        region.center = sm3dar.currentLocation.coordinate;
        region.span.longitudeDelta = 0.0001f;
        region.span.latitudeDelta = 0.0001f;
        [sm3dar.map setRegion:region animated:YES];
    }
}

- (void) loadPointsOfInterest
{
    // Add compass points.
    SM3DAR_Controller *sm3dar = [SM3DAR_Controller sharedController];
    CLLocationCoordinate2D currentLoc = [sm3dar currentLocation].coordinate;
    CLLocationDegrees lat=currentLoc.latitude;
    CLLocationDegrees lon=currentLoc.longitude;
    
    [self addPOI:@"N" subtitle:@"" latitude:(lat+0.01f) longitude:lon canReceiveFocus:NO];
    [self addPOI:@"S" subtitle:@"" latitude:(lat-0.01f) longitude:lon canReceiveFocus:NO];
    [self addPOI:@"E" subtitle:@"" latitude:lat longitude:(lon+0.01f) canReceiveFocus:NO];
    [self addPOI:@"W" subtitle:@"" latitude:lat longitude:(lon-0.01f) canReceiveFocus:NO];
    
    [self restoreSpot];
	[self updatePointer];

    [self performSelector:@selector(zoomMapIn) withObject:nil afterDelay:2.0];

    [self bringActiveScreenToFront];
}

- (void) buildScreen1
{
    if (screen1)
        return;
    
	UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 400, 320, 60)];
    [self.view addSubview:v];
    self.screen1 = v;
    [v release];

    UIView *bg = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 60)];
    bg.backgroundColor = [UIColor blackColor];
    bg.alpha = 0.2f;    
    [screen1 addSubview:bg];
    [bg release];

    // button
    self.parkButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [parkButton setTitle:BTN_TITLE_SET_SPOT forState:UIControlStateNormal];
    [parkButton addTarget:self action:@selector(toggleParkingSpot) forControlEvents:UIControlEventTouchUpInside];
    [parkButton sizeToFit];
    [screen1 addSubview:parkButton];
    parkButton.center = CGPointMake(160, 30);

    // crosshairs
    UIImage *img = [UIImage imageNamed:@"3dar_marker_icon1.png"];
    UIImageView *iv = [[UIImageView alloc] initWithImage:img];
    CGPoint p = self.view.center;
    iv.center = CGPointMake(p.x, p.y-16);
    [self.view addSubview:iv];
    self.crosshairs = iv;
    iv.alpha = 0.0f;
    [iv release];
}

- (void) buildHUD
{
    // compass
    self.compass = [[[PointerView alloc] initWithPadding:CGPointMake(10, 10) image:[UIImage imageNamed:@"compass_rose_g_300.png"]] autorelease];
    compass.delegate = self;

    // minimize the compass
    compass.currentScale = 0.3;
    compass.transform = CGAffineTransformMakeScale(compass.currentScale, compass.currentScale);
    [compass updateCenterPoint];
    
    [self.view addSubview:compass];

    // pointer
    self.pointer = [[[PointerView alloc] initWithPadding:CGPointMake(104, 104) image:[UIImage imageNamed:@"wedge_92.png"]] autorelease];
    pointer.delegate = self;
    [compass addSubview:pointer];    

    hudTimer = [NSTimer scheduledTimerWithTimeInterval:POINTER_UPDATE_SEC target:self selector:@selector(updateHUD) userInfo:nil repeats:YES];
}

- (void) viewDidLoad 
{
    NSLog(@"\n\nWCVC: viewDidLoad\n\n");
    [super viewDidLoad];
    
    SM3DAR_Controller *sm3dar = [SM3DAR_Controller sharedController];
    sm3dar.delegate = self;
    sm3dar.view.backgroundColor = [UIColor blackColor];
    [self.view addSubview:sm3dar.view];
    
    [self buildScreen1];        
    [self buildHUD];
    //	[self bringActiveScreenToFront];    
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload 
{
    NSLog(@"\n\nWCVC: viewDidUnload\n\n");
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}

- (void) bringActiveScreenToFront
{
	screen1.hidden = NO;
	crosshairs.hidden = NO;
    [self.view bringSubviewToFront:screen1];
}

- (void) locationManager:(CLLocationManager*)manager
    didUpdateToLocation:(CLLocation*)newLocation
           fromLocation:(CLLocation*)oldLocation 
{
    if (!parkingSpot && crosshairs.alpha < 0.1)
    {
        [self performSelector:@selector(showCrosshairs) withObject:nil afterDelay:2.0];
    }
}

- (CGPoint) centerPoint
{
	return CGPointMake(160, 220);    
}

- (void) showCrosshairs
{
    [self setCrosshairsHidden:NO];
}

- (void) setCrosshairsHidden:(BOOL)hide
{
    CGFloat alpha = (hide ? 0.0 : 1.0);
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.5];
    crosshairs.alpha = alpha;
    [UIView commitAnimations];
}

- (void) setParkingSpotLatitude:(CLLocationDegrees)latitude longitude:(CLLocationDegrees)longitude
{
    SM3DAR_Controller *sm3dar = [SM3DAR_Controller sharedController];
    self.parkingSpot = [self addPOI:@"P" subtitle:@"distance" latitude:latitude longitude:longitude canReceiveFocus:YES];
    
    UILabel *parkingSpotLabel = ((RoundedLabelMarkerView*)parkingSpot.view).label;
    parkingSpotLabel.backgroundColor = [UIColor darkGrayColor];
    parkingSpotLabel.textColor = [UIColor yellowColor];
    
    [sm3dar.map addAnnotation:parkingSpot];        
    
    [parkButton setTitle:BTN_TITLE_RESET_SPOT forState:UIControlStateNormal];
    [self setCrosshairsHidden:YES];
}

- (void) saveSpot
{
    PointOfInterest *poi = nil;

    if (parkingSpot)
    {
        NSDictionary *properties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithDouble:parkingSpot.coordinate.latitude], @"latitude",
                                    [NSNumber numberWithDouble:parkingSpot.coordinate.longitude], @"longitude",
                                    nil];
        
        poi = [[PointOfInterest alloc] initWithDictionary:properties];    
    }
    
    PREF_SAVE_OBJECT(PREF_KEY_LAST_POI, poi.dictionary);
    [poi release];
}

- (void) restoreSpot
{
    NSDictionary *properties = (NSDictionary*)PREF_READ_OBJECT(PREF_KEY_LAST_POI);
    NSLog(@"restoring: %@", properties);
    if (!properties)
        return;
    
    CLLocationDegrees latitude = [(NSNumber*)[properties objectForKey:@"latitude"] doubleValue];
    CLLocationDegrees longitude = [(NSNumber*)[properties objectForKey:@"longitude"] doubleValue];
    [self setParkingSpotLatitude:latitude longitude:longitude];
}

- (void) toggleParkingSpot
{
    SM3DAR_Controller *sm3dar = [SM3DAR_Controller sharedController];
    
    if (parkingSpot)
    {
        // remove it
        [sm3dar removePointOfInterest:parkingSpot];
        self.parkingSpot = nil;
        [self setCrosshairsHidden:NO];
        [parkButton setTitle:BTN_TITLE_SET_SPOT forState:UIControlStateNormal];
    }
    else
    {
        // drop a pin
        CLLocationCoordinate2D currentLoc = [sm3dar.map convertPoint:CGPointMake(160, 250)
                                                toCoordinateFromView:self.view];
        CLLocationDegrees lat = currentLoc.latitude;
        CLLocationDegrees lon = currentLoc.longitude;
        
        [self setParkingSpotLatitude:lat longitude:lon];
    }

	[self updatePointer];
    [self saveSpot];
}

- (void) didShowMap 
{
    [self bringActiveScreenToFront];
}

- (void) didHideMap 
{
	screen1.hidden = YES;
	crosshairs.hidden = YES;
}

- (void) updatePointer
{
    if (!parkingSpot)
    {
        pointer.hidden = YES;
        return;
    }
    
    pointer.hidden = NO;
    
    Coord3D worldPoint = parkingSpot.worldPoint;
    CGFloat x = worldPoint.x;
    CGFloat y = worldPoint.y;
    CGFloat radians = atan2(x, y);
    
    [pointer rotate:radians duration:(POINTER_UPDATE_SEC)];  
}

- (void) updateHUD
{
    if (!compass)
        return;
    
    SM3DAR_Controller *sm3dar = [SM3DAR_Controller sharedController];    
    if (abs(lastHeading - sm3dar.trueHeading) < HEADING_DELTA_THRESHOLD)
    	return;

    lastHeading = sm3dar.trueHeading;

    extern float degreesToRadians(float degrees);    
    CGFloat radians = -degreesToRadians(lastHeading);
    [compass rotate:radians duration:(POINTER_UPDATE_SEC*0.99)];  
}

- (void) pointerWasTapped:(PointerView*)pointerView
{
    [compass toggleState];
}

@end
