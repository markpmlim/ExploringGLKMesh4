//
//  OGLShader.h
//  ExploringGLKMesh
//
//  Created by mark lim pak mun on 10/12/2023.
//  Copyright © 2023 mark lim pak mun. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/gl3.h>

@interface OGLShader : NSObject

- (GLuint)compile:(NSString *) filename
       shaderType:(GLenum) type;
- (GLuint)linkShaders:(const GLuint *)shadersIDs
          shaderCount:(int)count
        deleteShaders:(BOOL)delete;

// public access
@property GLuint program;

@end
