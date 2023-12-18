## Exploring GLKMesh
<br />
<br />

We conclude the investigation on how to create **GLKMeshes** objects that can be used in OpenGL demos on the macOS and iOS with this demo. 


It is not necessary to create a **SCNScene** object from an loaded **MDLAsset**. For a simple .OBJ file, we could just access an instance of MDLMesh by using the instruction:


```objective-C

    MDLMesh *mdlMesh = (MDLMesh *)asset[0];


```

followed by the statement:


```objective-C

    SCNGeometry *scnGeometry = [SCNGeometry geometryWithMDLMesh:mdlMesh];

```

However, the Model class initializer of the previous demo expects the vertices of the .OBJ file passed as a parameter to have normals and texture coordinate attributes. To deal with .OBJ files which has no normals and texture coordinates declared, the logical thing to do is to perform a preliminary check on the **MDLMesh** object encapsulated in the **MDLAsset** object. The **MDLAsset** was loaded with 

        MDLAsset *asset = [[MDLAsset alloc] initWithURL:url
                                       vertexDescriptor:nil
                                        bufferAllocator:nil];


The Model class initializer, initWithURL: scans the array of vertex attributes (**MDLVertexAttribute**) using **MDLMesh**'s vertexDescriptor (**MDLVertexDescriptor**) property to determine if the mesh does have normal and texture coordinate attributes.

Then the initializer method prepares a custom vertex descriptor (**MDLVertexDescriptor**) with a single attribute layout (**MDLVertexBufferLayout**). For the initializer to work properly with the *prepareForOpenGL* method, it calls the 2 methods, **setPackedOffsets** and **setPackedStrides** (see Apple's API docs for detailed information) and then re-loads the **MDLAsset**.
 
```objective-C

        asset = [[MDLAsset alloc] initWithURL:url
                             vertexDescriptor:vertexDescriptor
                              bufferAllocator:nil];

```

Normals and texture coordinates are added to the mesh if necessary. The rest of the steps are straightforward.


It is obvious, by now, the following methods must always to call :

        meshWithSCNGeometry:bufferAllocator:

initWithMesh:error:

to create **GLKMesh** objects from an instance of **SCNGeometry**. 


<br />
<br />
<br />

Compiled and run under XCode 8.3.2
<br />
Tested on macOS 10.12
<br />
Deployment set at macOS 10.11.

<br />
<br />
<br />

Resources:

www.learnopengl.com

