/*
 * This file is part of the GrabKit package.
 * Copyright (c) 2012 Pierre-Olivier Simonard <pierre.olivier.simonard@gmail.com>
 *  
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and 
 * associated documentation files (the "Software"), to deal in the Software without restriction, including 
 * without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
 * copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the 
 * following conditions:
 *  
 * The above copyright notice and this permission notice shall be included in all copies or substantial 
 * portions of the Software.
 *  
 * The Software is provided "as is", without warranty of any kind, express or implied, including but not 
 * limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no
 * event shall the authors or copyright holders be liable for any claim, damages or other liability, whether
 * in an action of contract, tort or otherwise, arising from, out of or in connection with the Software or the 
 * use or other dealings in the Software.
 *
 * Except as contained in this notice, the name(s) of (the) Author shall not be used in advertising or otherwise
 * to promote the sale, use or other dealings in this Software without prior written authorization from (the )Author.
 */


#import "GRKPicasaGrabber.h"
#import "GRKPicasaQuery.h"
#import "GRKPicasaConnector.h"
#import "GRKPicasaSingleton.h"
#import "GRKPicasaConstants.h"

#import "GDataServiceGooglePhotos.h"
#import "GDataBaseElements.h"

@interface GRKPicasaGrabber()
-(GRKAlbum *) albumFromGDataEntryPhotoAlbum:(GDataEntryPhotoAlbum *) entry;
-(GRKPhoto *) photoFromGDataEntryPhoto:(GDataEntryPhoto *) entry;
@end


@implementation GRKPicasaGrabber


-(id) init {
    
    if ((self = [super initWithServiceName:kGRKServiceNamePicasa]) != nil){

        // Check that the constants are properly set.
        NSAssert( ! [kGRKPicasaClientId isEqualToString:@""], @"Picasa constant 'kGRKPicasaClientId' is not set." );
        NSAssert( ! [kGRKPicasaClientSecret isEqualToString:@""], @"Picasa constant 'kGRKPicasaClientSecret' is not set." ); 
        
    }     
    
    return self;
}


#pragma mark - GRKServiceGrabberConnectionProtocol methods

/* @see refer to GRKServiceGrabberConnectionProtocol documentation
 */
-(void) connectWithConnectionIsCompleteBlock:(GRKGrabberConnectionIsCompleteBlock)connectionIsCompleteBlock andErrorBlock:(GRKErrorBlock)errorBlock;
{
    
    // use a GRKPicasaConnector 
    __block GRKPicasaConnector * picasaConnector = [[GRKPicasaConnector alloc] initWithGrabberType:_serviceName];
    
    [picasaConnector  connectWithConnectionIsCompleteBlock:^(BOOL connected){

                    if ( connectionIsCompleteBlock != nil ){
                        dispatch_async(dispatch_get_main_queue(), ^{
                        connectionIsCompleteBlock(connected);
                        });
                    }
                    [picasaConnector release];	
        
                } andErrorBlock:^(NSError * error){

                    if ( errorBlock != nil ){    
                        dispatch_async(dispatch_get_main_queue(), ^{
                        errorBlock(error);
                        });
                    }
                    [picasaConnector release];	
        
                }];
    
}

/* @see refer to GRKServiceGrabberConnectionProtocol documentation
 */
-(void) disconnectWithDisconnectionIsCompleteBlock:(GRKGrabberDisconnectionIsCompleteBlock)disconnectionIsCompleteBlock;
{
    
    // use a GRKPicasaConnector 
    __block GRKPicasaConnector * picasaConnector = [[GRKPicasaConnector alloc] initWithGrabberType:_serviceName];
    
    [picasaConnector disconnectWithDisconnectionIsCompleteBlock:^(BOOL disconnected){
        
        if ( disconnectionIsCompleteBlock != nil ){
            dispatch_async(dispatch_get_main_queue(), ^{
            disconnectionIsCompleteBlock(disconnected);
            });
        }
        [picasaConnector release];	
        
    }];  
    
}

/* @see refer to GRKServiceGrabberConnectionProtocol documentation
 */
-(void) isConnected:(GRKGrabberConnectionIsCompleteBlock)connectedBlock;
{
    if ( connectedBlock == nil ) @throw NSInvalidArgumentException;
    
    // use a GRKPicasaConnector 
    __block GRKPicasaConnector * picasaConnector = [[GRKPicasaConnector alloc] initWithGrabberType:_serviceName];
    
    [picasaConnector isConnected:^(BOOL connected){
        
        dispatch_async(dispatch_get_main_queue(), ^{
        connectedBlock(connected);
        });
        [picasaConnector release];	
        
    }];
    
    
}


#pragma mark - GRKServiceGrabberProtocol methods

/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) albumsOfCurrentUserAtPageIndex:(NSUInteger)pageIndex
              withNumberOfAlbumsPerPage:(NSUInteger)numberOfAlbumsPerPage
                       andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock 
                          andErrorBlock:(GRKErrorBlock)errorBlock;
{

    
    if ( numberOfAlbumsPerPage > kGRKMaximumNumberOfAlbumsPerPage ) {
        
        NSException* exception = [NSException
                                  exceptionWithName:@"numberOfAlbumsPerPageTooHigh"
                                  reason:[NSString stringWithFormat:@"The number of albums per page you asked (%d) is too high", numberOfAlbumsPerPage]
                                  userInfo:nil];
        @throw exception;
    }

    
    // use pageIndex+1 because Picasa starts at page 1, and we start at page 0
	NSUInteger startIndex = (pageIndex * numberOfAlbumsPerPage)+1;
    NSMutableDictionary * paramsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                				 [NSNumber numberWithInt:numberOfAlbumsPerPage], @"max-results", 
                                				 [NSNumber numberWithInt:startIndex], @"start-index",
                              			nil];
	
    
    NSString * userId = [GRKPicasaSingleton sharedInstance].userEmailAdress;
    
	NSURL *albumsBaseFeedURL = [GDataServiceGooglePhotos photoFeedURLForUserID:userId
                                                                       albumID:nil 
                                                                     albumName:nil 
                                                                       photoID:nil 
                                                                          kind:@"album" 
                                                                        access:@"all"];
	
    __block GRKPicasaQuery * query = nil;
   
    query = [GRKPicasaQuery queryWithFeedURL:albumsBaseFeedURL 
                                  andParams:paramsDict
                          withHandlingBlock:^(GRKPicasaQuery *query, id result) {
                           
                              
                              if ( ! [result isKindOfClass:[GDataFeedPhotoUser class]] ){
                              
                                  if ( errorBlock != nil ){
                                      
                                      // Create an error for "bad format result" and call the errorBlock
                                      NSError * error = [self errorForBadFormatResultForAlbumsOperation];
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          errorBlock(error);
                                      });
                                  }
                                  [query release];
                                  return;     
                              }
                              
                              NSMutableArray * albums = [NSMutableArray array];
                              for( GDataEntryPhotoAlbum * entry in [(GDataFeedPhotoUser *)result entries]){
                                  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
                                  
                                  GRKAlbum * album = [self albumFromGDataEntryPhotoAlbum:entry];
                                  [albums addObject:album];
                                  
                                  [pool drain];
                              }
                              if ( completeBlock != nil ){
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                  completeBlock(albums);
                                  });
                              }
                              [self unregisterQueryAsLoading:query];
                              
                          } andErrorBlock:^(NSError *error) {
                              
                              if ( errorBlock != nil ){
                                  NSError * GRKError = [self errorForAlbumsOperationWithOriginalError:error];
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      errorBlock(GRKError);
                                  });

                              }
                              [self unregisterQueryAsLoading:query];
                          }];
    [self registerQueryAsLoading:query];
    [query perform];
}

/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) fillAlbum:(GRKAlbum *)album
withPhotosAtPageIndex:(NSUInteger)pageIndex
withNumberOfPhotosPerPage:(NSUInteger)numberOfPhotosPerPage
 andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock 
    andErrorBlock:(GRKErrorBlock)errorBlock;
{
    
    if ( numberOfPhotosPerPage > kGRKMaximumNumberOfPhotosPerPage ) {
        
        NSException* exception = [NSException
                                  exceptionWithName:@"numberOfPhotosPerPageTooHigh"
                                  reason:[NSString stringWithFormat:@"The number of photos per page you asked (%d) is too high", numberOfPhotosPerPage]
                                  userInfo:nil];
        @throw exception;
    }

    GDataFeedPhotoAlbum * albumFeed = [GDataFeedPhotoAlbum albumFeed];
    
    GDataBatchOperation *op;
    op = [GDataBatchOperation batchOperationWithType:kGDataBatchOperationQuery];
    [albumFeed setBatchOperation:op];    
    
    
    // use pageIndex+1 because Picasa starts at page 1, and we start at page 0
	NSUInteger startIndex = (pageIndex * numberOfPhotosPerPage)+1;
    
  	NSString * sizes = @"32u,48u,64u,72u,104u,144u,"
				       "150u,160u,94u,110u,128u,200u," 
                       "220u,288u,320u,400u,512u,576u,"
					   "640u,720u,800u,912u,1024u,"
                       "1152u,1280u,1440u,1600u";
    
    NSMutableDictionary * paramsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 				[NSNumber numberWithInt:numberOfPhotosPerPage], @"max-results", 
                                 				[NSNumber numberWithInt:startIndex], @"start-index",
			                                 	sizes,@"thumbsize",
                                 nil];
	
    
    NSString * userId = [GRKPicasaSingleton sharedInstance].userEmailAdress;

    
	NSURL *photosFeedURL = [GDataServiceGooglePhotos photoFeedURLForUserID:userId
																   albumID:album.albumId 
																 albumName:nil 
																   photoID:nil 
																	  kind:nil 
																	access:nil];
   
    __block GRKPicasaQuery * query = nil;
    
    query = [GRKPicasaQuery queryWithFeedURL:photosFeedURL 
                                  andParams:paramsDict
                          withHandlingBlock:^(GRKPicasaQuery *query, id result) {
                             
                              if ( ! [result isKindOfClass:[GDataFeedPhotoAlbum class]] ){

                                  if ( errorBlock != nil ){
                                  
                                      // Create an error for "bad format result" and call the errorBlock
                                      NSError * error = [self errorForBadFormatResultForFillAlbumOperationWithOriginalAlbum:album];
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          errorBlock(error);
                                      });

                                      dispatch_async(dispatch_get_main_queue(), ^{
                                      errorBlock([NSError errorWithDomain:@"" code:0 userInfo:nil]);
                                      });
                                  }
                                  
                                  [query release];
                                  return;     
                              }
                              
							  NSMutableArray * newPhotos = [NSMutableArray array];
                              
                              for( GDataEntryPhoto * entry in [(GDataFeedPhotoAlbum *)result entries] ){
                                  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
                                  
                                  GRKPhoto * photo = [self photoFromGDataEntryPhoto:entry];
                                  [newPhotos addObject:photo];
                                  
                                  [pool drain];
                              }
                              
                              [album addPhotos:newPhotos forPageIndex:pageIndex withNumberOfPhotosPerPage:numberOfPhotosPerPage];
                              if ( completeBlock != nil ){
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                  completeBlock(newPhotos);
                                  });
                              }
                              [self unregisterQueryAsLoading:query];
                              
                          } andErrorBlock:^(NSError *error) {
                              
                              if ( errorBlock != nil ){
                                  NSError * GRKError = [self errorForFillAlbumOperationWithOriginalError:error];
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      errorBlock(GRKError);
                                  });

                              }
                              [self unregisterQueryAsLoading:query];
                              
                          }];
             
    [self registerQueryAsLoading:query];
    [query perform];

    
}

/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) cancelAll {
    
    NSArray * queriesToCancel = [NSArray arrayWithArray:_queries];
    
    for( GRKPicasaQuery * query in queriesToCancel ){
        
        [query cancel];
        [self unregisterQueryAsLoading:query];
    }
    
}

/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) cancelAllWithCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock;
{
    [self cancelAll];
    if ( completeBlock != nil ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completeBlock(nil);
        });
    }
    
}



#pragma mark - Internal processing methods


/** Build and return a GRKAlbum from the given GDataEntryPhotoAlbum.
 
 @param entry a GDataEntryPhotoAlbum representing the album to build, as returned by Picasa's API
 @return an autoreleased GRKAlbum
 */
-(GRKAlbum *) albumFromGDataEntryPhotoAlbum:(GDataEntryPhotoAlbum *) entry;
{
	
	NSString * albumName = [(GDataAtomTitle *)[entry title] stringValue] ;
	NSString * albumId = [entry GPhotoID] ;
	NSDate * dateUpdated = [[(GDataEntryPhotoAlbum *)entry updatedDate] date]; 
	NSUInteger photosCount = [[entry photosUsed] integerValue];
	
    NSMutableDictionary * dates = [NSMutableDictionary dictionary];
	if ( dateUpdated != nil )
        [dates setObject:dateUpdated forKey:kGRKAlbumDatePropertyDateUpdated];
    
    
    GRKAlbum * album = [GRKAlbum albumWithId:albumId 
                                   andName:albumName 
                                  andCount:photosCount 
                       /*andPhotos:nil*/
                                  andDates:dates];
    
	return album;
	
}


/** Build and return a GRKPhoto from the given GDataEntryPhoto.
 
 @param entry a GDataEntryPhoto representing the photo to build, as returned by Picasa's API
 @return an autoreleased GRKPhoto
 */
-(GRKPhoto *) photoFromGDataEntryPhoto:(GDataEntryPhoto *) entry;
{
	
	NSString * photoName = [[entry title] stringValue] ;
    NSString * photoCaption = [[[entry mediaGroup] mediaDescription] stringValue];
	NSString * photoId = [entry GPhotoID] ;
    

	NSTimeInterval dateTakenTimestamp = [[entry timestamp] doubleValue]; 
	NSDate * dateTaken = [NSDate dateWithTimeIntervalSince1970:dateTakenTimestamp];
    
	NSUInteger originalImageWidth = [[entry width] intValue];
	NSUInteger originalImageHeight = [[entry height] intValue];
    
    NSArray * rawThumbnails = [[entry mediaGroup] mediaThumbnails];
	
    NSMutableDictionary * dates = [NSMutableDictionary dictionary];
	if ( dateTaken != nil )
        [dates setObject:dateTaken forKey:kGRKPhotoDatePropertyDateTaken];
                                   
                            	
    
    NSMutableArray * images = [NSMutableArray arrayWithCapacity:[rawThumbnails count]];
	for( GDataMediaThumbnail * tn in rawThumbnails ){
		NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
        
        NSUInteger imageWidth = [[tn width] intValue];
        NSUInteger imageHeight = [[tn height] intValue];
        BOOL isOriginal = (imageWidth == originalImageWidth && imageHeight == originalImageHeight);
        
        GRKImage * image = [GRKImage imageWithURLString:[tn URLString] 
                                             andWidth:imageWidth
                                            andHeight:imageHeight
                                           isOriginal:isOriginal];
        [images addObject:image];

        [pool drain];
    }
    
    GRKPhoto * photo = [GRKPhoto photoWithId:photoId 
                                   andCaption:photoCaption 
                                   andName:photoName 
                                 andImages:images
                                  andDates:dates];

	return photo;
	
}



@end
