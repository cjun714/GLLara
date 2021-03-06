//
//  GLLPoseExportViewController.h
//  GLLara
//
//  Created by Torsten Kammer on 31.01.13.
//  Copyright (c) 2013 Torsten Kammer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*!
 * @abstract Provides accessory view for exporting poses in XNALara format.
 * @discussion Main functionality: Set and read the selected radio button.
 */
@interface GLLPoseExportViewController : NSViewController

@property (nonatomic) NSUInteger selectionMode;
@property (nonatomic) BOOL exportUnusedBones;

@property (nonatomic) BOOL exportOnlySelectedBones;

@end
