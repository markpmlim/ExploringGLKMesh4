//
//  Model.m
//  ExploringGLKMesh
//
//  Created by mark lim pak mun on 18/12/2023.
//  Copyright © 2023 mark lim pak mun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>
#import <SceneKit/ModelIO.h>
#import <GLKit/GLKit.h>
#import "OGLShader.h"
#import "Model.h"


@implementation Model
{
    GLKMesh     *_glkMesh;
    GLuint      _vao;           // vertex array object

    GLuint      *_vbos;         // a dynamic array of vertex buffer objects
    GLuint      *_ebos;         // a dynamic array element/index buffer objects
    GLsizei     *_indicesCounts;
    GLenum      *_modes;
    GLenum      *_indexTypes;
    NSUInteger  *_indexBufferOffsets;

}

- (nullable instancetype)initCubeWithRadius:(GLfloat)radius
                              inwardNormals:(BOOL)inwardNormals
{
    self = [super init];
    if (self) {
        GLKMeshBufferAllocator *allocator = [[GLKMeshBufferAllocator alloc] init];

        MDLMesh *mdlMesh = [MDLMesh newBoxWithDimensions:(vector_float3){radius, radius, radius}
                                                segments:(vector_uint3){1, 1, 1}
                                            geometryType:MDLGeometryTypeTriangles
                                           inwardNormals:YES
                                               allocator:allocator];
        NSError *error = nil;
        _glkMesh = [[GLKMesh alloc] initWithMesh:mdlMesh
                                           error:&error];
        if (error != nil) {
            self = nil;
        }
        [self prepareForOpenGL];
    }
    return self;
}


- (nullable instancetype)initTorusWithRingRadius:(float)ringRadius
                                      pipeRadius:(float)pipeRadius
{
    self = [super init];
    if (self) {
        GLKMeshBufferAllocator *allocator = [[GLKMeshBufferAllocator alloc] init];
        SCNGeometry *torus = [SCNTorus torusWithRingRadius:ringRadius
                                                pipeRadius:pipeRadius];
        [SCNTransaction flush];
        // The GLKMesh object has a property labelled name which can
        // not be NIL.
        // Must give the SCNGeomtry object a name or it will crash when
        // the GLKMesh instance method initWithMesh:error: is called.
        torus.name = @"torus";
        MDLMesh *mdlMesh = [MDLMesh meshWithSCNGeometry:torus
                                        bufferAllocator:allocator];

        NSError *error = nil;
        _glkMesh = [[GLKMesh alloc] initWithMesh:mdlMesh
                                           error:&error];
        if (error != nil) {
            self = nil;
        }
        [self prepareForOpenGL];
    }
    return self;
}

/*
 It is mandatory for an .OBJ file have the position attribute
 for each vertex of its mesh. If the normal and uv coord attributes
 are missing, the instance MDLMesh methods

        addNormalsWithAttributeNamed:creaseThreshold: and
        addUnwrappedTextureCoordinatesForAttributeNamed:

 can be called to add surface normals and calculate the
 texture coordinates of each vertex of the mesh.
 */
- (nullable instancetype)initWithURL:(NSURL *_Nonnull)url
{
    self = [super init];
    if (self) {
        // First, we have to determine if the .OBJ has normals
        // and texture coordinate attributes
        MDLAsset *asset = [[MDLAsset alloc] initWithURL:url
                                       vertexDescriptor:nil
                                        bufferAllocator:nil];
        // We assume there is only one top level asset and
        // it is an instance of MDLMesh
        MDLMesh *mdlMesh = (MDLMesh *)asset[0];
        // We can check the mesh's name property is not nil.
        //NSLog(@"mesh name:%@", mdlMesh.name);
        MDLVertexDescriptor *vertDesc = [mdlMesh vertexDescriptor];
        BOOL hasNormals = NO;
        BOOL hasTexCoords = NO;
        for (int i=0; i<vertDesc.layouts.count; i++) {
            MDLVertexAttribute *vertAttribute = vertDesc.attributes[i];
            NSString *name = vertAttribute.name;
            if ([name isEqualToString:MDLVertexAttributeNormal])
                hasNormals = YES;
            if ([name isEqualToString:MDLVertexAttributeTextureCoordinate])
                hasTexCoords = YES;
        }

        // For .OBJ with only position attributes for its vertices, we need
        // to first declare an instance of MDLVertexDescriptor ...
        MDLVertexDescriptor *vertexDescriptor = [[MDLVertexDescriptor alloc] init];
        vertexDescriptor.attributes[0] = [[MDLVertexAttribute alloc] initWithName:MDLVertexAttributePosition
                                                                           format:MDLVertexFormatFloat3
                                                                           offset:0
                                                                      bufferIndex:0];
        vertexDescriptor.attributes[1] = [[MDLVertexAttribute alloc] initWithName:MDLVertexAttributeNormal
                                                                           format:MDLVertexFormatFloat3
                                                                           offset:3 * sizeof(float)
                                                                      bufferIndex:0];
        vertexDescriptor.attributes[2] = [[MDLVertexAttribute alloc] initWithName:MDLVertexAttributeTextureCoordinate
                                                                           format:MDLVertexFormatFloat2
                                                                           offset:6 * sizeof(float)
                                                                      bufferIndex:0];
        vertexDescriptor.layouts[0] = [[MDLVertexBufferLayout alloc] initWithStride:8 * sizeof(float)];

        // ... and then send the following messages to it.
        // At the same time, it will force 3 layouts to have the same stride value
        // so that we only need to use the stride from the first layout.
        // The GLKMesh object will have 3 vertex buffers but one submesh.
        [vertexDescriptor setPackedOffsets];
        [vertexDescriptor setPackedStrides];

        asset = [[MDLAsset alloc] initWithURL:url
                             vertexDescriptor:vertexDescriptor
                              bufferAllocator:nil];
        mdlMesh = (MDLMesh *)asset[0];
        //NSLog(@"%u %u %u", hasPositions, hasNormals, hasTexCoords);
        if (! hasNormals) {
            // According to documentation, normals will only be added if vertex data
            // will be used,
            [mdlMesh addNormalsWithAttributeNamed:MDLVertexAttributeNormal
                                  creaseThreshold:0.2];
        }
        // Unwrapping the texture coordinates might take a long time if the mesh
        // has hundreds of thousands of vertices.
        if (! hasTexCoords)
            [mdlMesh addUnwrappedTextureCoordinatesForAttributeNamed:MDLVertexAttributeTextureCoordinate];

        // We will be passing the node's `geometry` propery to the MDLMesh class method
        SCNGeometry *scnGeometry = [SCNGeometry geometryWithMDLMesh:mdlMesh];
        //NSLog(@"%@", scnGeometry);
        // Instantiate an appropriate Mesh Buffer Allocator.
        GLKMeshBufferAllocator *allocator = [[GLKMeshBufferAllocator alloc] init];
        MDLMesh *newMDLMesh = [MDLMesh meshWithSCNGeometry:scnGeometry
                                           bufferAllocator:allocator];
        NSError *error = nil;
        _glkMesh = [[GLKMesh alloc] initWithMesh:newMDLMesh
                                           error:&error];
        // The method above will return a NIL object if
        // there is an error.
        if (error != nil) {
            self = nil;
            //NSLog(@"%@", error);
        }
        [self prepareForOpenGL];
    }
    return self;
}

- (void)dealloc
{
    glDeleteVertexArrays(1, &_vao);
    // We assume the VBOs and EBOs are deleted by the system.
    free(_vbos);
    free(_ebos);
    free(_indicesCounts);
    free(_modes);
    free(_indexTypes);
    free(_indexBufferOffsets);
}
    
- (void)render
{
    glBindVertexArray(_vao);
    // Note: the EBO is internally bound to the VAO.
    for (int i=0; i<_glkMesh.submeshes.count; i++) {
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _ebos[i]);
        glDrawElements(_modes[i], _indicesCounts[i], _indexTypes[i],
                       (const void *)_indexBufferOffsets[i]);
    }
}

/*
 Extract the values that were assigned to the various properties.
 */
    
- (void)prepareForOpenGL
{
    glGenVertexArrays(1, &_vao);
    glBindVertexArray(_vao);
    MDLVertexDescriptor *vertDesc = _glkMesh.vertexDescriptor;
    // All built-in parametric MDLMeshes have position, normal and tex coords attributes in that order.
    MDLVertexAttribute *posAttr = [vertDesc attributeNamed:MDLVertexAttributePosition];
    // MDLVertexAttributeData is not available for GLKMesh so we access an element of
    // the array of MDLVertexBufferLayouts
    // When there is more than 1 layouts, it seems all have the same stride value.
    NSUInteger stride = vertDesc.layouts[0].stride;
    //printf("stride:%lu\n", stride);
    // There may be more than One Vertex Buffer
    _vbos = malloc(_glkMesh.vertexBuffers.count * sizeof(GLuint));
    for (int i=0; i<_glkMesh.vertexBuffers.count; i++) {
        _vbos[i] = _glkMesh.vertexBuffers[i].glBufferName;
        //printf("VBO ID:%u\n", _vbos[i]);
        // the data may be in separate areas.
        //NSLog(@"%@", _glkMesh.vertexBuffers[i].map);
        //glBindBuffer(GL_ARRAY_BUFFER, _vbos[i]);
        // Assumes the system will bind
    }
    GLKVertexAttributeParameters vertAttrParms = GLKVertexAttributeParametersFromModelIO(posAttr.format);
    // We need the stride, format and offset properties to call
    // glEnableVertexAttribArray & glVertexAttribPointer
    // The vertex shader should precede the position attribute with the phrase
    // layout(location = 0)
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0,
                          vertAttrParms.size,           // # of components - 1, 2, 3 or 4
                          vertAttrParms.type,           // e.g. GL_FLOAT
                          vertAttrParms.normalized,     // usually 0 (false)
                          (GLsizei)stride,
                          (const void *)posAttr.offset);
    MDLVertexAttribute *normalAttr = [vertDesc attributeNamed:MDLVertexAttributeNormal];
    //stride = vertDesc.layouts[1].stride;
    //printf("stride:%lu\n", stride);
    vertAttrParms = GLKVertexAttributeParametersFromModelIO(normalAttr.format);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1,
                          vertAttrParms.size,
                          vertAttrParms.type,
                          vertAttrParms.normalized,
                          (GLsizei)stride,
                          (const void *)normalAttr.offset);
    MDLVertexAttribute *texCoordAttr = [vertDesc attributeNamed:MDLVertexAttributeTextureCoordinate];
    //stride = vertDesc.layouts[2].stride;
    //printf("stride:%lu\n", stride);
    vertAttrParms = GLKVertexAttributeParametersFromModelIO(texCoordAttr.format);
    glEnableVertexAttribArray(2);
    glVertexAttribPointer(2,
                          vertAttrParms.size,
                          vertAttrParms.type,
                          vertAttrParms.normalized,
                          (GLsizei)stride,
                          (const void *)texCoordAttr.offset);
    //NSLog(@"%@ %@ %@", posAttr, normalAttr, texCoordAttr);
    // There may be more than only 1 element in the array of submeshes etc.
    // We require the following values to perform glBindBuffer ...
    for (int i=0; i<_glkMesh.submeshes.count; i++) {
        _ebos = malloc(_glkMesh.submeshes.count * sizeof(GLuint));
        _modes = malloc(_glkMesh.submeshes.count * sizeof(GLenum));
        _indexTypes = malloc(_glkMesh.submeshes.count * sizeof(GLenum));
        _indicesCounts = malloc(_glkMesh.submeshes.count * sizeof(GLsizei));
        _indexBufferOffsets = malloc(_glkMesh.submeshes.count * sizeof(NSUInteger));
    }

    // ...  and glDrawElements
    for (int i=0; i<_glkMesh.submeshes.count; i++) {
        _ebos[i] = _glkMesh.submeshes[0].elementBuffer.glBufferName;
        //printf("EBO ID:%u\n", _ebos[i]);
        // An example of mode is GL_TRIANGLES
        _modes[i] = _glkMesh.submeshes[0].mode;
        // An example of type is GL_UNSIGNED_SHORT
        _indexTypes[i] = _glkMesh.submeshes[0].type;
        // # of elements in the elementBuffer (GLKMeshBuffer).
        _indicesCounts[i] = _glkMesh.submeshes[0].elementCount;
        // offset, in bytes, into the element buffer (usually 0)
        _indexBufferOffsets[i] = _glkMesh.submeshes[0].elementBuffer.offset;
    }
}
    
@end

