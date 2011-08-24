//
//  PeteyPabloPlugin.h
//  PeteyPablo
//
//  Created by Jean-Pierre Mouilleseaux on 18 Aug 2011.
//  Copyright (c) 2011 Chorded Constructions. All rights reserved.
//

#import <Quartz/Quartz.h>

@class SSWindow;

@interface PeteyPabloPlugIn : QCPlugIn {
    SSWindow* _window;
    PDFView* _pdfView;
    CGImageRef _renderedImage;
    id<QCPlugInOutputImageProvider> _placeHolderProvider;

    NSUInteger _destinationWidth;
    NSUInteger _destinationHeight;
    BOOL _doneSignal;
    BOOL _doneSignalDidChange;
}
@property (nonatomic, assign) NSString* inputFileLocation;
@property (nonatomic) NSUInteger inputPageNumber;
@property (nonatomic) NSUInteger inputDestinationWidth;
@property (nonatomic) NSUInteger inputDestinationHeight;
@property (nonatomic) BOOL inputRenderSignal;
@property (nonatomic, assign) id<QCPlugInOutputImageProvider> outputImage;
@property (nonatomic) BOOL outputDoneSignal;
@end
