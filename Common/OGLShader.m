//
//  OGLShader.m
//  ExploringGLKMesh
//
//  Created by mark lim pak mun on 10/12/2023.
//  Copyright © 2023 mark lim pak mun. All rights reserved.
//

#import "OGLShader.h"


@implementation OGLShader
{
    GLuint _program;
}
 ;

- (GLuint)compile:(NSString *)filename
       shaderType:(GLenum) type
{

    NSError *outErr = nil;
    const GLchar *shaderSourcePointer;
    NSBundle *bundle = [NSBundle mainBundle];
    NSArray<NSString *> *components = [filename componentsSeparatedByString:@"."];
    NSURL *resourceURL = [bundle URLForResource:components[0]
                                  withExtension:components[1]];

    shaderSourcePointer = (GLchar *)[[NSString stringWithContentsOfFile:[resourceURL path]
                                                               encoding:NSUTF8StringEncoding
                                                                  error:&outErr] UTF8String];
    //NSLog(@"%s", shaderSourcePointer);
    GLuint shaderID = glCreateShader(type);
    glShaderSource(shaderID, 1, &shaderSourcePointer , NULL);
    glCompileShader(shaderID);
    // Check shader has been compiled w/o errors
    int infoLogLength;
    glGetShaderiv(shaderID, GL_INFO_LOG_LENGTH, &infoLogLength);
    if ( infoLogLength > 0 ) {
        GLchar *shaderErrorMessage = (GLchar *)malloc(infoLogLength);
        glGetShaderInfoLog(shaderID, infoLogLength, NULL, shaderErrorMessage);
        //NSLog(@"error: %s", shaderErrorMessage);
        free(shaderErrorMessage);
    }
    GLint compiled = GL_FALSE;
    glGetShaderiv(shaderID, GL_COMPILE_STATUS, &compiled);
    if (compiled == 0) {
        glDeleteShader(shaderID);
        return 0;
    }
    return shaderID;
}

- (GLuint)linkShaders:(const GLuint *)shadersIDs
          shaderCount:(int)count
        deleteShaders:(BOOL)delete
{

    GLuint programID = glCreateProgram();
    for (int i=0; i < count; i++)
        glAttachShader(programID, shadersIDs[i]);

    glLinkProgram(programID);
    GLint linked;
    glGetProgramiv(programID, GL_LINK_STATUS, &linked);
    if ( !linked ) {
        GLsizei infoLen;
        glGetProgramiv( programID, GL_INFO_LOG_LENGTH, &infoLen );
        GLchar *errorMessage = (GLchar *)malloc(infoLen);
        glGetProgramInfoLog( programID, infoLen, &infoLen, errorMessage );
        NSLog(@"%s", errorMessage);
        free(errorMessage);
        for (int i=0; i < count; i++)
            glDeleteShader(shadersIDs[i]);
        return 0;
    }
    if (delete) {
        for (int i=0; i < count; i++)
            glDeleteShader(shadersIDs[i]);
    }
    self.program = programID;
    return programID;
}

@end
