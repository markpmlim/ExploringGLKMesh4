//
//  VirtualCamera.m
//  ExploringGLKMesh
//
//  Created by mark lim pak mun on 10/12/2023.
//  Copyright © 2023 mark lim pak mun. All rights reserved.
//

#include <TargetConditionals.h>
#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>

@interface VirtualCamera : NSObject

- (nonnull instancetype)initWithScreenSize:(CGSize)size;

- (void)update:(float)duration;

- (void)resizeWithSize:(CGSize)newSize;

- (void)startDraggingFromPoint:(CGPoint)point;

- (void)dragToPoint:(CGPoint)point;

- (void)endDrag;

- (void)zoomInOrOut:(float)amount;

@property (nonatomic) GLKVector3 position;
@property (nonatomic) GLKMatrix4 viewMatrix;
@property (nonatomic) GLKQuaternion orientation;
@property (nonatomic, getter=isDragging) BOOL dragging;

@end
