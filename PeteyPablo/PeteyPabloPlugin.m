//
//  PeteyPabloPlugIn.m
//  PeteyPablo
//
//  Created by Jean-Pierre Mouilleseaux on 18 Aug 2011.
//  Copyright (c) 2011 Chorded Constructions. All rights reserved.
//

#import "PeteyPabloPlugIn.h"

// WORKAROUND - radar://problem/9927446 Lion added QCPlugInAttribute key constants not weak linked
#pragma weak QCPlugInAttributeCategoriesKey
#pragma weak QCPlugInAttributeExamplesKey

#ifdef DEBUG
    #define CCDebugLogSelector() NSLog(@"-[%@ %@]", /*NSStringFromClass([self class])*/self, NSStringFromSelector(_cmd))
    #define CCDebugLog(a...) NSLog(a)
    #define CCWarningLog(a...) NSLog(a)
    #define CCErrorLog(a...) NSLog(a)
#else
    #define CCDebugLogSelector()
    #define CCDebugLog(a...)
    #define CCWarningLog(a...) NSLog(a)
    #define CCErrorLog(a...) NSLog(a)
#endif

#define CCLocalizedString(key, comment) [[NSBundle bundleForClass:[self class]] localizedStringForKey:(key) value:@"" table:(nil)]


static NSString* const PPExampleCompositionName = @"";
static NSUInteger PPMainScreenWidth = 0;
static NSUInteger PPMainScreenHeight = 0;

@implementation PeteyPabloPlugIn

@dynamic inputFileLocation, inputPageNumber, inputDestinationWidth, inputDestinationHeight, inputRenderSignal, outputImage, outputDoneSignal;

+ (void)initialize {
    PPMainScreenWidth = NSWidth([[NSScreen mainScreen] frame]);
    PPMainScreenHeight = NSHeight([[NSScreen mainScreen] frame]);
}

+ (NSDictionary*)attributes {
    NSMutableDictionary* attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
        CCLocalizedString(@"kQCPlugIn_Name", NULL), QCPlugInAttributeNameKey, 
        CCLocalizedString(@"kQCPlugIn_Description", NULL), QCPlugInAttributeDescriptionKey, 
        nil];

#if defined(MAC_OS_X_VERSION_10_7) && (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_7)
    if (&QCPlugInAttributeCategoriesKey != NULL) {
        // array with category strings
        NSArray* categories = [NSArray arrayWithObjects:@"Source", nil];
        [attributes setObject:categories forKey:QCPlugInAttributeCategoriesKey];
    }
    if (&QCPlugInAttributeExamplesKey != NULL) {
        // array of file paths or urls relative to plugin resources
        NSArray* examples = [NSArray arrayWithObjects:[[NSBundle bundleForClass:[self class]] URLForResource:PPExampleCompositionName withExtension:@"qtz"], nil];
        [attributes setObject:examples forKey:QCPlugInAttributeExamplesKey];
    }
#endif

    return (NSDictionary*)attributes;
}

+ (NSDictionary*)attributesForPropertyPortWithKey:(NSString*)key {
    if ([key isEqualToString:@"inputFileLocation"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Location", QCPortAttributeNameKey, nil];
    else if ([key isEqualToString:@"inputPageNumber"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Page Number", QCPortAttributeNameKey, 
            [NSNumber numberWithUnsignedInteger:1], QCPortAttributeMinimumValueKey, 
            [NSNumber numberWithUnsignedInteger:10000], QCPortAttributeMaximumValueKey, 
            [NSNumber numberWithUnsignedInteger:1], QCPortAttributeDefaultValueKey, nil];
    else if ([key isEqualToString:@"inputDestinationWidth"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Width Pixels", QCPortAttributeNameKey, 
            [NSNumber numberWithUnsignedInteger:0], QCPortAttributeMinimumValueKey, 
            [NSNumber numberWithUnsignedInteger:10000], QCPortAttributeMaximumValueKey, 
            [NSNumber numberWithUnsignedInteger:PPMainScreenWidth], QCPortAttributeDefaultValueKey, nil];
    else if ([key isEqualToString:@"inputDestinationHeight"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Height Pixels", QCPortAttributeNameKey, 
            [NSNumber numberWithUnsignedInteger:0], QCPortAttributeMinimumValueKey, 
            [NSNumber numberWithUnsignedInteger:10000], QCPortAttributeMaximumValueKey, 
            [NSNumber numberWithUnsignedInteger:PPMainScreenHeight], QCPortAttributeDefaultValueKey, nil];
    else if ([key isEqualToString:@"inputRenderSignal"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Render Signal", QCPortAttributeNameKey, nil];
    else if ([key isEqualToString:@"outputImage"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
    else if ([key isEqualToString:@"outputDoneSignal"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Done Signal", QCPortAttributeNameKey, nil];
	return nil;
}

+ (QCPlugInExecutionMode)executionMode {
	return kQCPlugInExecutionModeProvider;
}

+ (QCPlugInTimeMode)timeMode {
	return kQCPlugInTimeModeIdle;
}

#pragma mark -

- (id)init {
	self = [super init];
	if (self) {
        _destinationWidth = PPMainScreenWidth;
        _destinationHeight = PPMainScreenHeight;
	}
	return self;
}

#pragma mark - EXECUTION

- (BOOL)startExecution:(id <QCPlugInContext>)context {
	/*
	Called by Quartz Composer when rendering of the composition starts: perform any required setup for the plug-in.
	Return NO in case of fatal failure (this will prevent rendering of the composition to start).
	*/

    CCDebugLogSelector();

	return YES;
}

- (void)enableExecution:(id <QCPlugInContext>)context {
	/*
	Called by Quartz Composer when the plug-in instance starts being used by Quartz Composer.
	*/
}

- (BOOL)execute:(id <QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments {
	/*
	Called by Quartz Composer whenever the plug-in instance needs to execute.
	Only read from the plug-in inputs and produce a result (by writing to the plug-in outputs or rendering to the destination OpenGL context) within that method and nowhere else.
	Return NO in case of failure during the execution (this will prevent rendering of the current frame to complete).
	
	The OpenGL context for rendering can be accessed and defined for CGL macros using:
	CGLContextObj cgl_ctx = [context CGLContextObj];
	*/

	return YES;
}

- (void)disableExecution:(id <QCPlugInContext>)context {
	/*
	Called by Quartz Composer when the plug-in instance stops being used by Quartz Composer.
	*/

    CCDebugLogSelector();
}

- (void)stopExecution:(id <QCPlugInContext>)context {
	/*
	Called by Quartz Composer when rendering of the composition stops: perform any required cleanup for the plug-in.
	*/

    CCDebugLogSelector();
}

@end
