//
//  Model.h
//  ExploringGLKMesh
//
//  Created by mark lim pak mun on 18/12/2023.
//  Copyright © 2023 mark lim pak mun. All rights reserved.
//

#import <Foundation/Foundation.h>
@class Mesh;


@interface Model: NSObject

// public methods
// To add more parametric meshes
- (nullable instancetype)initCubeWithRadius:(GLfloat)radius
                              inwardNormals:(BOOL)inwardNormals;

- (nullable instancetype)initTorusWithRingRadius:(float)ringRadius
                                      pipeRadius:(float)pipeRadius;

- (nullable instancetype)initWithURL:(NSURL *_Nonnull)url;

- (void) render;

@end
