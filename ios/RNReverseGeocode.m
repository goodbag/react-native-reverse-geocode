#import <MapKit/MapKit.h>
#import "RNReverseGeocode.h"
#import <React/RCTConvert.h>
#import <CoreLocation/CoreLocation.h>
#import <React/RCTConvert+CoreLocation.h>
#import <React/RCTUtils.h>

@interface RCTConvert (Mapkit)

+ (MKCoordinateSpan)MKCoordinateSpan:(id)json;
+ (MKCoordinateRegion)MKCoordinateRegion:(id)json;

@end

@implementation RCTConvert(MapKit)

+ (MKCoordinateSpan)MKCoordinateSpan:(id)json
{
    json = [self NSDictionary:json];
    return (MKCoordinateSpan){
        [self CLLocationDegrees:json[@"latitudeDelta"]],
        [self CLLocationDegrees:json[@"longitudeDelta"]]
    };
}

+ (MKCoordinateRegion)MKCoordinateRegion:(id)json
{
    return (MKCoordinateRegion){
        [self CLLocationCoordinate2D:json],
        [self MKCoordinateSpan:json]
    };
}

@end

@implementation RNReverseGeocode
{
    MKLocalSearch *localSearch;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE()

- (NSArray *)formatLocalSearchCallback:(MKLocalSearchResponse *)localSearchResponse
{
    NSMutableArray *RCTResponse = [[NSMutableArray alloc] init];
    
    for (MKMapItem *mapItem in localSearchResponse.mapItems) {
        NSMutableDictionary *formedLocation = [[NSMutableDictionary alloc] init];
        
        // Get MUID
        // https://stackoverflow.com/questions/24300138/ios-mkmapitem-how-get-access-to-all-members/24303634#24303634
        NSValue *place = [mapItem valueForKey:@"place"];
        NSArray *businessArray = (NSArray *)[place valueForKey:@"business"];
        
        NSNumber *uid=nil;

        if (businessArray != nil && businessArray.count >0) {
             id geobusiness=businessArray[0];
             uid=[geobusiness valueForKey:@"uID"];
        }
        
        [formedLocation setValue:mapItem.name forKey:@"name"];
        [formedLocation setValue:mapItem.url.absoluteURL forKey:@"absoluteUrl"];
        [formedLocation setValue:mapItem.url.absoluteString forKey:@"absoluteStrUrl"];
        if (@available(iOS 9.0, *)) {
            [formedLocation setValue:mapItem.timeZone forKey:@"timeZone"];
        } else {
            // Fallback on earlier versions
        }
        [formedLocation setObject:[NSNumber numberWithBool:mapItem.isCurrentLocation] forKey:@"isCurrentLocation"];
        if (@available(iOS 13.0, *)) {
            [formedLocation setValue:mapItem.pointOfInterestCategory forKey:@"pointOfInterestCategory"];
        } else {
            // Fallback on earlier versions
        }
        [formedLocation setValue:mapItem.placemark.title forKey:@"address"];
        [formedLocation setValue:[uid stringValue] forKey:@"muid"];
        [formedLocation setValue:@{@"latitude": @(mapItem.placemark.coordinate.latitude),
                                   @"longitude": @(mapItem.placemark.coordinate.longitude)} forKey:@"location"];
        
        [RCTResponse addObject:formedLocation];
    }
    
    return [RCTResponse copy];
}

RCT_EXPORT_METHOD(searchForLocations:(NSString *)searchText near:(MKCoordinateRegion)region callback:(RCTResponseSenderBlock)callback)
{
    [localSearch cancel];
    
    MKLocalSearchRequest *searchRequest = [[MKLocalSearchRequest alloc] init];
    searchRequest.naturalLanguageQuery = searchText;
    searchRequest.region = region;

    localSearch = [[MKLocalSearch alloc] initWithRequest:searchRequest];
    
    __weak RNReverseGeocode *weakSelf = self;
    [localSearch startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        
        if (error) {
            callback(@[RCTMakeError(@"Failed to make local search. ", error, @{@"key": searchText}), [NSNull null]]);
        } else {
            NSArray *RCTResponse = [weakSelf formatLocalSearchCallback:response];
            callback(@[[NSNull null], RCTResponse]);
        }
    }];
}

@end
