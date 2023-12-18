//
//  OpenGLView.m
//  SphericalProjection (aka EquiRectangular Projection)
//
//  Created by mark lim pak mun on 18/12/2023.
//  Copyright © 2023 Incremental Innovation. All rights reserved.
//

#import <GLKit/GLKit.h>
#import <OpenGL/gl3.h>
#import "OpenGLView.h"
#import "OGLShader.h"
#import "Model.h"
#import "VirtualCamera.h"

#define CheckGLError() { \
    GLenum err = glGetError(); \
    if (err != GL_NO_ERROR) { \
        printf("CheckGLError: %04x caught at %s:%u\n", err, __FILE__, __LINE__); \
    } \
}


@implementation OpenGLView
{
    OGLShader       *skyboxShader;
    OGLShader       *bunnyShader;
    
    Model           *skybox;
    Model           *bunny;

    GLKTextureInfo  *cubemapTexInfo;

    GLKMatrix4      _projectionMatrix;
    GLint           _modelMatrixLoc;
    GLint           _viewMatrixLoc;
    GLint           _projectionMatrixLoc;
    GLint           _normalMatrixLoc;
    GLint           _skyboxMapLoc;
 
    CVDisplayLinkRef displayLink;
    double           deltaTime;
    float           _angle;
    VirtualCamera   *_camera;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    NSOpenGLPixelFormat *pf = [OpenGLView basicPixelFormat];
    self = [super initWithFrame:frameRect
                    pixelFormat:pf];
    if (self) {
        NSOpenGLContext *glContext = [[NSOpenGLContext alloc] initWithFormat:pf
                                                                shareContext:nil];
        self.pixelFormat = pf;
        self.openGLContext = glContext;
        // This call should be made for OpenGL 3.2 or later shaders
        // to be compiled and linked w/o problems.
        [[self openGLContext] makeCurrentContext];
        CGSize size = CGSizeMake(frameRect.size.width, frameRect.size.height);
        _camera = [[VirtualCamera alloc] initWithScreenSize:size];
    }
    return self;
}

// seems ok to use NSOpenGLProfileVersion4_1Core
+ (NSOpenGLPixelFormat*)basicPixelFormat
{
    NSOpenGLPixelFormatAttribute attributes[] = {
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADoubleBuffer,        // double buffered
        NSOpenGLPFADepthSize, 24,       // 24-bit depth buffer
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        (NSOpenGLPixelFormatAttribute)0
    };
    return [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
}

// overridden method of NSOpenGLView
- (void)prepareOpenGL
{
    [super prepareOpenGL];
    [self compileAndLinkShaders];
    [self loadTextures];
    [self loadModel];
    glCullFace(GL_BACK);
    CheckGLError();

    // Create a display link capable of being used with all active displays
    CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);

    // Set the renderer output callback function
    CVDisplayLinkSetOutputCallback(displayLink,
                                   &MyDisplayLinkCallback,
                                   (__bridge void * _Nullable)(self));
    CVDisplayLinkStart(displayLink);
}

- (void)dealloc
{
    CVDisplayLinkStop(displayLink);
}

- (CVReturn)getFrameForTime:(const CVTimeStamp*)outputTime
{
    // deltaTime is unused in this bare bones demo, but here's how to calculate it using display link info
    // should be = 1/60
    deltaTime = 1.0 / (outputTime->rateScalar * (double)outputTime->videoTimeScale / (double)outputTime->videoRefreshPeriod);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsDisplay:YES];
    });
    return kCVReturnSuccess;
}

// This is the renderer output callback function. The displayLinkContext object
// can be a custom (C struct) object or Objective-C instance.
static CVReturn MyDisplayLinkCallback(CVDisplayLinkRef displayLink,
                                      const CVTimeStamp* now,
                                      const CVTimeStamp* outputTime,
                                      CVOptionFlags flagsIn,
                                      CVOptionFlags* flagsOut,
                                      void* displayLinkContext)
{
    CVReturn result = [(__bridge OpenGLView *)displayLinkContext getFrameForTime:outputTime];
    return result;
}

- (void)compileAndLinkShaders
{
    GLuint shaderIDs[2];

    skybox = [[Model alloc] initCubeWithRadius:10.0
                                 inwardNormals:YES];

    skyboxShader = [[OGLShader alloc] init];
    shaderIDs[0] = [skyboxShader compile:@"Skybox.vs"
                              shaderType:GL_VERTEX_SHADER];
    shaderIDs[1] = [skyboxShader compile:@"Skybox.fs"
                              shaderType:GL_FRAGMENT_SHADER];
    [skyboxShader linkShaders:shaderIDs
                  shaderCount:2
                deleteShaders:YES];

    glUseProgram(skyboxShader.program);
    // The statement below is not necessay because there is only 1 texture.
    _skyboxMapLoc = glGetUniformLocation(skyboxShader.program, "cubeMap");
    CheckGLError();

    bunnyShader = [[OGLShader alloc] init];
    shaderIDs[0] = [bunnyShader compile:@"Reflect.vs"
                             shaderType:GL_VERTEX_SHADER];
    CheckGLError()
    shaderIDs[1] = [bunnyShader compile:@"Reflect.fs"
                             shaderType:GL_FRAGMENT_SHADER];
    [bunnyShader linkShaders:shaderIDs
                 shaderCount:2
               deleteShaders:YES];
    CheckGLError()

    // Once only
    glUseProgram(bunnyShader.program);
    _normalMatrixLoc  = glGetUniformLocation(bunnyShader.program, "normalMatrix");
    glUseProgram(0);

}

- (void)loadTextures
{
    glUseProgram(skyboxShader.program);
    NSError *outError = nil;
    // The resolution of the equirectangular image should be 6:1.
    NSString *path = [[NSBundle mainBundle] pathForResource:@"skybox_image"
                                                     ofType:@"jpg"];
    NSDictionary *texOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithBool:YES], GLKTextureLoaderGenerateMipmaps,
                                nil];
    cubemapTexInfo = [GLKTextureLoader cubeMapWithContentsOfFile:path
                                                         options:texOptions
                                                           error:&outError];
    if (outError != nil) {
        NSLog(@"Error loading equirectangular texture:%@", outError);
    }
    glUniform1i(_skyboxMapLoc, 0);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_CUBE_MAP, cubemapTexInfo.name);

    glUseProgram(0);
}

/*
 The vertices of the .OBJ file of this demo only has position attributes.
 */
- (void)loadModel
{
    NSBundle *mainBndl = [NSBundle mainBundle];
    NSURL* assetURL = [mainBndl URLForResource:@"bunny"
                                 withExtension:@"obj"];
    bunny = [[Model alloc] initWithURL:assetURL];
}

// This method must be called periodically to ensure
// the camera's internal objects are updated.
- (void)updateCamera
{
    [_camera update:deltaTime];
    _angle += deltaTime;
}

- (void)render
{
    [self updateCamera];
    CGLLockContext([[self openGLContext] CGLContextObj]);
    glClearColor(0.5, 0.5, 0.5, 1.0);
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
    glEnable(GL_DEPTH_TEST);

    GLKMatrix4 viewMatrix = _camera.viewMatrix;
    GLKMatrix4  modelMatrix = GLKMatrix4MakeScale(2.0, 2.0, 2.0);
    modelMatrix = GLKMatrix4TranslateWithVector3(modelMatrix, GLKVector3Make(0, 0, 1));
    modelMatrix = GLKMatrix4Rotate(modelMatrix, _angle, 1, 1, 1);
    GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
    bool isInvertible = NO;
    GLKMatrix4 normalMatrix4 = GLKMatrix4InvertAndTranspose(modelViewMatrix,
                                                            &isInvertible);
    GLKMatrix3 normalMatrix3 = GLKMatrix4GetMatrix3(normalMatrix4);
    glUseProgram(bunnyShader.program);
    _modelMatrixLoc = glGetUniformLocation(bunnyShader.program, "modelMatrix");
    _viewMatrixLoc = glGetUniformLocation(bunnyShader.program, "viewMatrix");
    _projectionMatrixLoc = glGetUniformLocation(bunnyShader.program, "projectionMatrix");
    glUniformMatrix4fv(_modelMatrixLoc, 1, GL_FALSE, modelMatrix.m);
    glUniformMatrix4fv(_viewMatrixLoc, 1, GL_FALSE, viewMatrix.m);
    glUniformMatrix4fv(_projectionMatrixLoc, 1, GL_FALSE, _projectionMatrix.m);
    glUniformMatrix3fv(_normalMatrixLoc, 1, GL_FALSE, normalMatrix3.m);
    glActiveTexture(GL_TEXTURE0);   // Texture unit 0
    glBindTexture(GL_TEXTURE_CUBE_MAP, cubemapTexInfo.name);
    [bunny render];

    // Render the skybox last.
    // Note: the depth function must be set to less than or equal to so that
    // the skybox depth values (which are all 1.0s) will pass the test.
    glDepthFunc(GL_LEQUAL);
    modelMatrix = GLKMatrix4MakeWithQuaternion(_camera.orientation);
    _modelMatrixLoc = glGetUniformLocation(skyboxShader.program, "modelMatrix");
    _viewMatrixLoc = glGetUniformLocation(skyboxShader.program, "viewMatrix");
    _projectionMatrixLoc = glGetUniformLocation(skyboxShader.program, "projectionMatrix");

    glUseProgram(skyboxShader.program);
    glUniformMatrix4fv(_modelMatrixLoc, 1, GL_FALSE, modelMatrix.m);
    glUniformMatrix4fv(_viewMatrixLoc, 1, GL_FALSE, viewMatrix.m);
    glUniformMatrix4fv(_projectionMatrixLoc, 1, GL_FALSE, _projectionMatrix.m);
    glActiveTexture(GL_TEXTURE0);   // Texture unit 0
    glBindTexture(GL_TEXTURE_CUBE_MAP, cubemapTexInfo.name);
    [skybox render];
    glDepthFunc(GL_LESS);       // Set depth function back to default
    glUseProgram(0);

    CGLUnlockContext([[self openGLContext] CGLContextObj]);
    CGLFlushDrawable([[self openGLContext] CGLContextObj]);
}

// overridden method
-(void)reshape
{
    NSRect frame = [self frame];
    glViewport(0, 0, frame.size.width, frame.size.height);
    GLfloat aspectRatio = frame.size.height/frame.size.width;
    _projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(50.0),
                                                 1.0f / aspectRatio,
                                                 0.1, 1000.0);
    CGSize size = CGSizeMake(frame.size.width, frame.size.height);
    [_camera resizeWithSize:size];
}

// overridden method
- (void)drawRect:(NSRect)dirtyRect
{
    [self render];
}

// these methods may need to be overridden or key events will not be detected.
- (BOOL)acceptsFirstResponder
{
    return YES;
} // acceptsFirstResponder

- (BOOL)becomeFirstResponder
{
    return  YES;
} // becomeFirstResponder

- (BOOL)resignFirstResponder
{
    return YES;
} // resignFirstResponder


- (void)mouseDown:(NSEvent *)event
{
    NSPoint mouseLocation = [self convertPoint:event.locationInWindow
                                      fromView:nil];
    [_camera startDraggingFromPoint:mouseLocation];
}

// rotational movement about x- and y-axis
- (void)mouseDragged:(NSEvent *)event
{
    NSPoint mouseLocation = [self convertPoint:event.locationInWindow
                                      fromView:nil];
    if (_camera.isDragging) {
        [_camera dragToPoint:mouseLocation];
    }
}

- (void) mouseUp:(NSEvent *)event
{
    NSPoint mouseLocation = [self convertPoint:event.locationInWindow
                                      fromView:nil];
    [_camera endDrag];
}

// The camera is at the centre of the scene so
// we don't have to support zooming in and out.
- (void)scrollWheel:(NSEvent *)event
{
    //CGFloat dz = event.scrollingDeltaY;
    //[_camera zoomInOrOut:dz];
}

- (void)keyDown:(NSEvent *)event
{
    if (event)
    {
        NSString* pChars = [event characters];
        if ([pChars length] != 0)
        {
            unichar key = [[event characters] characterAtIndex:0];
            switch(key) {
            case 27:
                exit(0);
                break;
            default:
                break;
            }
        }
    }
}


@end
