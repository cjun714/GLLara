//
//  GLLMeshDrawer.h
//  GLLara
//
//  Created by Torsten Kammer on 01.09.12.
//  Copyright (c) 2012 Torsten Kammer. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "simd_types.h"

@class GLLModelMesh;
@class GLLProgram;
@class GLLResourceManager;

/*!
 * @abstract Draws a single textured mesh.
 * @discussion This class contains only the mesh data, the program for rendering and the textures. In the future, both the program and the textures might be moved to the TransformedMeshDrawer, leaving this with only the geometry. There is one mesh drawer per mesh per loaded model. Several TransformedMeshDrawers can share one.
 */
@interface GLLMeshDrawer : NSObject

- (id)initWithMesh:(GLLModelMesh *)mesh resourceManager:(GLLResourceManager *)resourceManager error:(NSError *__autoreleasing*)error;

@property (nonatomic, retain, readonly) GLLModelMesh *modelMesh;
@property (nonatomic, retain, readonly) GLLProgram *program;
@property (nonatomic, copy, readonly) NSArray *textures;

- (void)draw;

- (void)unload;

@end
