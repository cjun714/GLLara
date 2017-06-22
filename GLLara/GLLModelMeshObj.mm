//
//  GLLModelMeshObj.m
//  GLLara
//
//  Created by Torsten Kammer on 12.09.12.
//  Copyright (c) 2012 Torsten Kammer. All rights reserved.
//

#import "GLLModelMeshObj.h"

#import <AppKit/NSColor.h>

#import "GLLModel.h"
#import "GLLModelParams.h"
#import "GLLTiming.h"

@implementation GLLModelMeshObj

- (id)initWithObjFile:(GLLObjFile *)file mtlFiles:(const std::vector<GLLMtlFile *> &)mtlFiles range:(const GLLObjFile::MaterialRange &)range inModel:(GLLModel *)model error:(NSError *__autoreleasing*)error;
{
    if (!(self = [super initAsPartOfModel:model])) return nil;
    
    GLLBeginTiming("OBJ mesh postprocess");
    
    // Procedure: Go through the indices in the range. For each index, load the vertex data from the file and put it in the vertex buffer here. Adjust the index, too.
    
    self.countOfUVLayers = 1;
    
    GLLBeginTiming("OBJ mesh vertex copy");
    std::unordered_map<unsigned, uint32_t> globalToLocalVertices;
    NSMutableData *vertices = [[NSMutableData alloc] initWithCapacity:(sizeof(GLLObjFile::VertexData) + sizeof(float[4])) * (range.end - range.start)];
    uint32_t *elementData = (uint32_t *) malloc(sizeof(uint32_t)*(range.end - range.start));
    
    for (unsigned i = range.start; i < range.end; i++)
    {
        unsigned globalIndex = file->getIndices().at(i);
        uint32_t index = 0;
        auto localIndexIter = globalToLocalVertices.find(globalIndex);
        if (localIndexIter == globalToLocalVertices.end())
        {
            // Add adjusted element
            index = (uint32_t) globalToLocalVertices.size();
            globalToLocalVertices[globalIndex] = index;
            elementData[i - range.start] = index;
            
            // Add vertex
            const GLLObjFile::VertexData &vertex = file->getVertexData().at(globalIndex);
            
            [vertices appendBytes:vertex.vert length:sizeof(vertex.vert)];
            [vertices appendBytes:vertex.norm length:sizeof(vertex.norm)];
            [vertices appendBytes:vertex.color length:sizeof(vertex.color)];
            float texCoordY = 1.0f - vertex.tex[1]; // Turn tex coords around (because I don't want to swap the whole image)
            [vertices appendBytes:vertex.tex length:sizeof(vertex.tex[0])];
            [vertices appendBytes:&texCoordY length:sizeof(vertex.tex[1])];
            
            // Space for tangents
            float zero[4] = { 0, 0, 0, 0 };
            [vertices appendBytes:&zero length:sizeof(zero)];
            
            // No bone weights or indices here; OBJs use special shaders that don't use them.
        }
        else
            elementData[i - range.start] = localIndexIter->second;
    }
    
    // Necessary postprocessing
    GLLEndTiming("OBJ mesh vertex copy");
    GLLBeginTiming("OBJ mesh tangents");
    [self calculateTangents:vertices];
    GLLEndTiming("OBJ mesh tangents");
    
    GLLBeginTiming("OBJ mesh params");
    // Set up other attributes
    self.vertexData = vertices;
    self.elementData = [NSData dataWithBytesNoCopy:elementData length:sizeof(uint32_t) * (range.end - range.start) freeWhenDone:YES];
    self.countOfVertices = globalToLocalVertices.size();
    self.countOfElements = range.end - range.start;
    
    // Previous actions may have disturbed vertex format (because it also depends on count of vertices) so uncache it.
    self.vertexFormat = nil;
    
    // Setup material
    // Three options: Diffuse, DiffuseSpecular, DiffuseNormal, DiffuseSpecularNormal
    GLLModelParams *objModelParams = [GLLModelParams parametersForName:@"objFileParameters" error:error];
    NSAssert(objModelParams, @"obj file parameters must always exist");
    
    const GLLMtlFile::Material *material = NULL;
    for (auto iter = mtlFiles.begin(); iter != mtlFiles.end(); iter++)
    {
        if ((*iter)->hasMaterial(range.materialName))
        {
            material = (*iter)->getMaterial(range.materialName);
            break;
        }
    }
    if (material) {
        if (material->specularTexture == NULL && material->normalTexture == NULL)
        {
            if (material->diffuseTexture != NULL)
            {
                self.textures = @[ (__bridge NSURL *) material->diffuseTexture ];
                self.shader = [objModelParams shaderNamed:@"DiffuseOBJ"];
            }
            else
            {
                self.textures = @[];
                self.shader = [objModelParams shaderNamed:@"TexturelessOBJ"];
            }
        }
        else if (material->specularTexture != NULL && material->normalTexture == NULL)
        {
            self.textures = @[ (__bridge NSURL *) material->diffuseTexture, (__bridge NSURL *) material->specularTexture ];
            self.shader = [objModelParams shaderNamed:@"DiffuseSpecularOBJ"];
        }
        else if (material->specularTexture == NULL && material->normalTexture != NULL)
        {
            self.textures = @[ (__bridge NSURL *) material->diffuseTexture, (__bridge NSURL *) material->normalTexture ];
            self.shader = [objModelParams shaderNamed:@"DiffuseNormalOBJ"];
        }
        else if (material->specularTexture != NULL && material->normalTexture != NULL)
        {
            self.textures = @[ (__bridge NSURL *) material->diffuseTexture, (__bridge NSURL *) material->specularTexture, (__bridge NSURL *) material->normalTexture ];
            self.shader = [objModelParams shaderNamed:@"DiffuseSpecularNormalOBJ"];
        }
        self.renderParameterValues = @{ @"ambientColor" : [NSColor colorWithCalibratedRed:material->ambient[0] green:material->ambient[1] blue:material->ambient[2] alpha:material->ambient[3]],
                                        @"diffuseColor" : [NSColor colorWithCalibratedRed:material->diffuse[0] green:material->diffuse[1] blue:material->diffuse[2] alpha:material->diffuse[3]],
                                        @"specularColor" : [NSColor colorWithCalibratedRed:material->specular[0] green:material->specular[1] blue:material->specular[2] alpha:material->specular[3]],
                                        @"specularExponent": @(material->shininess)
                                        };
    } else {
        self.textures = @[];
        self.shader = [objModelParams shaderNamed:@"TexturelessOBJ"];
        self.renderParameterValues = @{ @"ambientColor" : [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0],
                                        @"diffuseColor" : [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0],
                                        @"specularColor" : [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0],
                                        @"specularExponent": @(1.0)
                                        };
    }
    
    // Always use blending, since I can't prove that it doesn't otherwise.
    self.usesAlphaBlending = YES;
    
    GLLEndTiming("OBJ mesh params");
    GLLEndTiming("OBJ mesh postprocess");
    
    return self;
}

- (BOOL)hasBoneWeights
{
    return NO; // OBJ files don't use them. They do use one bone matrix, for the model position, but that's it.
}

@end
