//  Created by Timothy Sanders on 4/4/14.
//
//

extern NSString * coreDataResetNotificationKey;

@interface HJSCoreDataCenter : NSObject

// These strings will be displayed when reportDataError is called.
// If they are not set then a generic message will be used.
@property (nonatomic) NSString *errorEmailHeader;
@property (nonatomic) NSString *errorEmailSubject;
@property (nonatomic) NSString *errorNoEmailAlertMessage;

+ (instancetype)defaultCenter;

- (NSManagedObjectContext *)context;

- (void)requestSave;
- (void)immediateSave; // Mostly a debugging aid, but can be useful to force a save RIGHT NOW

- (void)reportDataError;

@end
