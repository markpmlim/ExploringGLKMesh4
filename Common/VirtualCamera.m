//
//  VirtualCamera.m
//  ExploringGLKMesh
//
//  Created by mark lim pak mun on 10/12/2023.
//  Copyright © 2023 mark lim pak mun. All rights reserved.
//

#import "VirtualCamera.h"

@implementation VirtualCamera
{
    // Instance variables backing the properties declared in the header file.
    GLKMatrix4 _viewMatrix;
    GLKQuaternion _orientation;
    BOOL _dragging;

    // All these instance vars are private
    float _sphereRadius;
    CGSize _screenSize;

    // Use to compute the viewmatrix
    GLKVector3 _eye;
    GLKVector3 _target;
    GLKVector3 _up;

    GLKVector3 _startPoint;
    GLKVector3 _endPoint;
    GLKQuaternion _previousQuat;
    GLKQuaternion _currentQuat;
}

- (nonnull instancetype)initWithScreenSize:(CGSize)size
{
    self = [super init];
    if (self != nil) {
        _screenSize = size;
        _sphereRadius = 1.0f;

    _viewMatrix = GLKMatrix4Identity;
       _eye = GLKVector3Make(0.0f, 0.0f, 3.0f);
    _target = GLKVector3Make(0.0f, 0.0f, 0.0f);
        _up =  GLKVector3Make(0.0f, 1.0f, 0.0f);

    _orientation  = GLKQuaternionIdentity;
    _previousQuat = GLKQuaternionIdentity;
    _currentQuat  = GLKQuaternionIdentity;

    _startPoint = GLKVector3Make(0,0,0);
      _endPoint = GLKVector3Make(0,0,0);
    }
    return self;
}

-(void)updateViewMatrix
{
    // OpenGL follows the right hand rule with +z direction out of the screen.
    _viewMatrix = GLKMatrix4MakeLookAt(_eye.x, _eye.y, _eye.z,
                                       _target.x, _target.y, _target.z,
                                       _up.x, _up.y, _up.z);
    
}

// This method must be called periodically otherwise the
// viewMatrix and orientation objects will not be updated.
- (void)update:(float)duration
{
    _orientation = _currentQuat;
    [self updateViewMatrix];
}

// Handle resize.
- (void)resizeWithSize:(CGSize)newSize
{
    _screenSize = newSize;
}

- (GLKQuaternion)rotationBetweenVector:(GLKVector3)from
                             andVector:(GLKVector3)to
{

    GLKVector3 u = GLKVector3Normalize(from);
    GLKVector3 v = GLKVector3Normalize(to);

    
    // Angle between the 2 vectors
    float cosTheta = GLKVector3DotProduct(u, v);
    GLKVector3 rotationAxis;
    
    if (cosTheta < -1 + 0.001f) {
        rotationAxis = GLKVector3CrossProduct(GLKVector3Make(0.0f, 0.0f, 1.0f), u);
        float length2 = GLKVector3DotProduct(rotationAxis, rotationAxis);
        if ( length2 < 0.01f ) {
            // Bad luck, they were parallel, try again!
            rotationAxis = GLKVector3CrossProduct(GLKVector3Make(1.0f, 0.0f, 0.0f), u);
        }
        
        rotationAxis = GLKVector3Normalize(rotationAxis);
        return GLKQuaternionMakeWithAngleAndVector3Axis(GLKMathDegreesToRadians(180.0f), rotationAxis);
    }

    // Compute rotation axis.
    rotationAxis = GLKVector3CrossProduct(u, v);
    
    float angle = acosf(cosTheta);
    // Normalising the axis should produce a unit-norm quaternion.
    rotationAxis = GLKVector3Normalize(rotationAxis);
    GLKQuaternion q = GLKQuaternionMakeWithAngleAndVector3Axis(-angle, rotationAxis);

    return q;

}

/*
 Project the mouse coords on to a sphere of radius 1.0 units.
 Use the mouse distance from the centre of screen as arc length on the sphere
 x = R * sin(a) * cos(b)
 y = R * sin(a) * sin(b)
 z = R * cos(a)
 where a = angle on x-z plane, b = angle on x-y plane
 
 NOTE:  the calculation of arc length is an estimation using linear distance
 from screen center (0,0) to the cursor position.
 
 */

- (GLKVector3)projectMouseX:(GLfloat)x
                       andY:(GLfloat)y
{
    
    float s = sqrtf(x*x + y*y);             // length between mouse coords and screen center
    float theta = s / _sphereRadius;        // s = r * θ
    float phi = atan2f(y, x);               // angle on x-y plane
    float x2 = _sphereRadius * sinf(theta); // x rotated by θ on x-z plane
    
    GLKVector3 vec;
    vec.x = x2 * cosf(phi);
    vec.y = x2 * sinf(phi);
    vec.z = _sphereRadius * cosf(theta);
    
    return vec;
    
}

// Handle mouse interactions.

// Response to a mouse down.
- (void)startDraggingFromPoint:(CGPoint)point
{
    self.dragging = YES;
    // The origin of macOS' display is at the bottom left corner.
    // The origin of iOS' display is at the top left corner
    // Remap so that the origin is at the centre of the display.
    // Range of mouseY: [-1.0, 1.0]
    float mouseX = (2*point.x - _screenSize.width)/_screenSize.width;
#if defined(TARGET_OS_IOS)
    // Invert the y-coordinate
    // Range of mouseY: [-1.0, 1.0]
    float mouseY = (_screenSize.height - 2*point.y )/_screenSize.height;
#else
    float mouseY = (2*point.y - _screenSize.height)/_screenSize.height;
#endif
    _startPoint = [self projectMouseX:mouseX
                                 andY:mouseY];
    // Save it for the mouse dragged
    _previousQuat = _currentQuat;
}

// Respond to a mouse dragged
- (void)dragToPoint:(CGPoint)point
{
    float mouseX = (2*point.x - _screenSize.width)/_screenSize.width;
#if defined(TARGET_OS_IOS)
    // Invert the y-coordinate
    // Range of mouseY: [-1.0, 1.0]
    float mouseY = (_screenSize.height - 2*point.y )/_screenSize.height;
#else
    float mouseY = (2*point.y - _screenSize.height)/_screenSize.height;
#endif
    _endPoint = [self projectMouseX:mouseX
                               andY:mouseY];
    GLKQuaternion delta = [self rotationBetweenVector:_startPoint
                                            andVector:_endPoint];
    //_currentQuat = simd_mul(delta, _previousQuat);
    _currentQuat = GLKQuaternionMultiply(delta, _previousQuat);
}

// Response to a mouse up
- (void)endDrag
{
    self.dragging = NO;
    _previousQuat = _currentQuat;
    _orientation = _currentQuat;
}

// Assume only a mouse with 1 scroll wheel.
- (void)zoomInOrOut:(float)amount
{
    static float kmouseSensitivity = 0.1;
    GLKVector3 pos = _eye;
    // OpenGL follows the right hand rule with +z direction out of the screen.
    float z = pos.z - amount*kmouseSensitivity;
    if (z >= 8.0f)
        z = 8.0f;
    else if (z <= 3.0f)
        z = 3.0f;
    _eye = GLKVector3Make(0.0, 0.0, z);
    self.position = _eye;
}

@end

