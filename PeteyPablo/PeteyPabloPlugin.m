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


static NSString* const PPExampleCompositionName = @"Art Importation";
static NSUInteger PPMainScreenWidth = 0;
static NSUInteger PPMainScreenHeight = 0;

static void _BufferReleaseCallback(const void* address, void* context) {
    CCDebugLog(@"_BufferReleaseCallback");
    // release bitmap context backing
    free((void*)address);
}

@interface PeteyPabloPlugIn()
@property (nonatomic, strong) id <QCPlugInOutputImageProvider> placeHolderProvider;
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
    CGPDFDocumentRelease(_document);
    CGPDFPageRelease(_page);

	[super finalize];
}

- (void)dealloc {
    CGPDFDocumentRelease(_document);
    CGPDFPageRelease(_page);
}

#pragma mark - EXECUTION

- (BOOL)startExecution:(id <QCPlugInContext>)context {
    CCDebugLogSelector();

	return YES;
}

- (void)enableExecution:(id <QCPlugInContext>)context {
    CCDebugLogSelector();
}

- (BOOL)execute:(id <QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments {
    // update outputs when appropriate
    if (_doneSignalDidChange) {
        // set image on done
        if (_doneSignal) {
            // TODO - move this somewhere convenient
            CGRect boxRect = CGPDFPageGetBoxRect(_page, kCGPDFMediaBox);
            CGFloat scale = fmin(_destinationWidth / boxRect.size.width, _destinationHeight / boxRect.size.height);

            size_t renderedImageWidth = boxRect.size.width * scale;
            size_t bytesPerRow = renderedImageWidth * 4;
            if (bytesPerRow % 16)
                bytesPerRow = ((bytesPerRow / 16) + 1) * 16;

            size_t renderedImageHeight = boxRect.size.height * scale;
            double totalBytes = renderedImageHeight * bytesPerRow;
            void* baseAddress = valloc(totalBytes);
            if (baseAddress == NULL) {
                CCErrorLog(@"ERROR - failed to valloc %f bytes for bitmap data to write into", totalBytes);
                return NO;
            }

//            CCDebugLog(@"update output image to %fx%f", (double)renderedImageWidth, (double)renderedImageHeight);

            CGContextRef bitmapContext = CGBitmapContextCreate(baseAddress, renderedImageWidth, renderedImageHeight, 8, bytesPerRow, [context colorSpace], kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
            if (bitmapContext == NULL) {
                CCErrorLog(@"ERROR - failed to create bitmap context");
                free(baseAddress);
                return NO;
            }
            CGRect bounds = CGRectMake(0., 0., renderedImageWidth, renderedImageHeight);
            CGContextClearRect(bitmapContext, bounds);
            CGContextScaleCTM(bitmapContext, scale, scale);
            CGContextDrawPDFPage(bitmapContext, _page);
            CGContextRelease(bitmapContext);

            self.placeHolderProvider = [context outputImageProviderFromBufferWithPixelFormat:QCPlugInPixelFormatBGRA8 pixelsWide:renderedImageWidth pixelsHigh:renderedImageHeight baseAddress:baseAddress bytesPerRow:bytesPerRow releaseCallback:_BufferReleaseCallback releaseContext:NULL colorSpace:[context colorSpace] shouldColorMatch:YES];
            self.outputImage = self.placeHolderProvider;
        }

        self.outputDoneSignal = _doneSignal;
        _doneSignalDidChange = _doneSignal;
        _doneSignal = NO;
    }

    BOOL shouldLoadURL = [self didValueForInputKeyChange:@"inputFileLocation"] && ![self.inputFileLocation isEqualToString:@""];
    BOOL shouldChangePage = shouldLoadURL || (_document && [self didValueForInputKeyChange:@"inputPageNumber"]);
    BOOL shouldResize = [self didValueForInputKeyChange:@"inputDestinationWidth"] || [self didValueForInputKeyChange:@"inputDestinationHeight"];
    BOOL shouldRender = shouldLoadURL || shouldChangePage || shouldResize || ([self didValueForInputKeyChange:@"inputRenderSignal"] && self.inputRenderSignal);
    // bail when possible
    if (!shouldLoadURL && !shouldChangePage && !shouldResize && !shouldRender) {
        return YES;
    }

    CCDebugLogSelector();

    // resize when appropriate
    if (shouldResize) {
        if (self.inputDestinationWidth == 0 || self.inputDestinationHeight == 0) {
            CCErrorLog(@"ERROR - invalid dimensions %lux%lu", (unsigned long)self.inputDestinationWidth, (unsigned long)self.inputDestinationHeight);
            return NO;
        }
        _destinationWidth = self.inputDestinationWidth;
        _destinationHeight = self.inputDestinationHeight;
        CCDebugLog(@"resize content to %lux%lu", (unsigned long)_destinationWidth, (unsigned long)_destinationHeight);
    }

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

        CGPDFDocumentRelease(_document);
        _document = CGPDFDocumentCreateWithURL((__bridge CFURLRef)url);
        if (!_document) {
            CCErrorLog(@"ERROR - failed to create PDF from URL %@", url);
            return NO;
        }
    }

    if (shouldChangePage) {
        CGPDFPageRelease(_page);
        _page = CGPDFDocumentGetPage(_document, self.inputPageNumber);
        if (!_page) {
            CCErrorLog(@"ERROR - unable to get page %lu", (unsigned long)self.inputPageNumber);
            return NO;
        }
        CGPDFPageRetain(_page);
    }

    if (shouldRender) {
        // kickstart image rendering
        _doneSignal = YES;
        _doneSignalDidChange = YES;
    }

	return YES;
}

- (void)disableExecution:(id <QCPlugInContext>)context {
    CCDebugLogSelector();
}

- (void)stopExecution:(id <QCPlugInContext>)context {
    CCDebugLogSelector();
}

@end
