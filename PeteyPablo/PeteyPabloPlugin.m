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


#pragma mark WINDOW

@interface SSWindow : NSWindow
@end
@implementation SSWindow
- (BOOL)isOpaque {
    return NO;
}
- (NSColor*)backgroundColor {
    return [NSColor clearColor];
}
@end

#pragma mark - PLUGIN

static NSString* const PPExampleCompositionName = @"";
static NSUInteger PPMainScreenWidth = 0;
static NSUInteger PPMainScreenHeight = 0;

/*
static void _BufferReleaseCallback(const void* address, void* context) {
    CCDebugLog(@"_BufferReleaseCallback");
    // release bitmap context backing
    free((void*)address);
}
*/

@interface PeteyPabloPlugIn()
@property (nonatomic, strong) id <QCPlugInOutputImageProvider> placeHolderProvider;
- (void)_setupWindow;
- (void)_teardownWindow;
- (void)_captureImageFromPDFView;
@end

@implementation PeteyPabloPlugIn

@dynamic inputFileLocation, inputPageNumber, inputDestinationWidth, inputDestinationHeight, inputRenderSignal, outputImage, outputDoneSignal;
@synthesize placeHolderProvider = _placeHolderProvider;

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

- (void)finalize {
    [self _teardownWindow];
    CGImageRelease(_renderedImage);

	[super finalize];
}

- (void)dealloc {
    [self _teardownWindow];
    CGImageRelease(_renderedImage);
}

#pragma mark - EXECUTION

- (BOOL)startExecution:(id <QCPlugInContext>)context {
    CCDebugLogSelector();

    [self _setupWindow];

	return YES;
}

- (void)enableExecution:(id <QCPlugInContext>)context {
    CCDebugLogSelector();
}

- (BOOL)execute:(id <QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments {
    BOOL shouldResize = [self didValueForInputKeyChange:@"inputDestinationWidth"] || [self didValueForInputKeyChange:@"inputDestinationHeight"];
    BOOL shouldLoadURL = [self didValueForInputKeyChange:@"inputFileLocation"] && ![self.inputFileLocation isEqualToString:@""];
    BOOL shouldChangePage = shouldLoadURL || [self didValueForInputKeyChange:@"inputPageNumber"];
    BOOL shouldRender = shouldResize || ([self didValueForInputKeyChange:@"inputRenderSignal"] && self.inputRenderSignal);

    // resize when appropriate
    if (shouldResize) {
        if (self.inputDestinationWidth == 0 || self.inputDestinationHeight == 0) {
            CCErrorLog(@"ERROR - invalid dimensions %lux%lu", (unsigned long)self.inputDestinationWidth, (unsigned long)self.inputDestinationHeight);
            return NO;
        }
        _destinationWidth = self.inputDestinationWidth;
        _destinationHeight = self.inputDestinationHeight;
        CCDebugLog(@"resize content to %lux%lu", (unsigned long)_destinationWidth, (unsigned long)_destinationHeight);
        [_window setContentSize:NSMakeSize(_destinationWidth, _destinationHeight)];
    }
    // bail when new render is not necessary
    if (!shouldLoadURL && !shouldRender) {
        return YES;
    }

    CCDebugLogSelector();

    if (shouldLoadURL) {
        NSURL* url = [NSURL URLWithString:self.inputFileLocation];
        // scheme-less would suggest a relative file url
        if (![url scheme]) {
            NSURL* baseDirectoryURL = [[context compositionURL] URLByDeletingLastPathComponent];
//            NSString* cleanFilePath = [[[baseDirectoryURL path] stringByAppendingPathComponent:self.inputFileLocation] stringByStandardizingPath];
//            CCDebugLog(@"cleaned file path: %@", cleanFilePath);
            url = [baseDirectoryURL URLByAppendingPathComponent:self.inputFileLocation];

            // TODO - may be better to just let it fail later?
            if (![url checkResourceIsReachableAndReturnError:NULL]) {
                return YES;
            }
        }

//        dispatch_async(dispatch_get_main_queue(), ^{
            PDFDocument* doc = [[PDFDocument alloc] initWithURL:url];
            if (!doc) {
                CCErrorLog(@"ERROR - failed to create PDF document from URL");
                return NO;
            }
            _pdfView.document = doc;
//        });
    }
    if (shouldChangePage) {
        PDFDocument* doc = _pdfView.document;
        [_pdfView goToPage:[doc pageAtIndex:self.inputPageNumber]];
    }
    if (shouldRender) {
        [self _captureImageFromPDFView];
    }

	return YES;
}

- (void)disableExecution:(id <QCPlugInContext>)context {
    CCDebugLogSelector();
}

- (void)stopExecution:(id <QCPlugInContext>)context {
    CCDebugLogSelector();
}

#pragma mark - PRIVATE

- (void)_setupWindow {
    CCDebugLogSelector();

    _window = [[SSWindow alloc] initWithContentRect:NSMakeRect(-16000., -16000., _destinationWidth, _destinationHeight) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
    _pdfView = [[PDFView alloc] initWithFrame:NSMakeRect(0., 0., _destinationWidth, _destinationHeight)];
    _pdfView.displayMode = kPDFDisplaySinglePage;
    _pdfView.autoScales = YES;
    [_window setContentView:_pdfView];
}

- (void)_teardownWindow {
    CCDebugLogSelector();

    [_window setContentView:nil];
    _pdfView = nil;

    [_window close];
    _window = nil;
}

- (void)_captureImageFromPDFView {
    CCDebugLogSelector();

//    dispatch_async(dispatch_get_main_queue(), ^{
        // size to fit
        NSSize pageSize = [_pdfView.currentPage boundsForBox:_pdfView.displayBox].size;
        // NB - mostly just useful for the aspect ratio,
        BOOL shouldResize = !NSEqualSizes([(NSView*)[_window contentView] bounds].size, pageSize);
        if (shouldResize) {
            [_window setContentSize:pageSize];
        }

        NSBitmapImageRep* bitmap = [_pdfView bitmapImageRepForCachingDisplayInRect:[_pdfView visibleRect]];
        [_pdfView cacheDisplayInRect:[_pdfView visibleRect] toBitmapImageRep:bitmap];

        NSString* path = [NSString stringWithFormat:@"/tmp/SS-%f.png", [[NSDate date] timeIntervalSince1970]];
        [[bitmap representationUsingType:NSPNGFileType properties:nil] writeToFile:path atomically:YES];

        CGImageRelease(_renderedImage);
        _renderedImage = CGImageRetain([bitmap CGImage]);

        _doneSignal = YES;
        _doneSignalDidChange = YES;
//    });
}

@end
