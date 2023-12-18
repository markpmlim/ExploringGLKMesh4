#version 330 core

// Incoming per vertex... vPosition and texture coordinates
layout (location = 0) in vec3 vPosition;

uniform mat4   projectionMatrix;
uniform mat4   modelMatrix;
uniform mat4   viewMatrix;

// Output to the fragment shader
smooth out vec3 texCoords;

void main(void)
{
	// Pass vPosition as the 3D texture coordinates
	texCoords = vPosition;

	// Don't forget to transform the geometry!
    vec4 pos = projectionMatrix * viewMatrix * modelMatrix * vec4(vPosition, 1.0);
    // The OpenGL function glDepthFunc(GL_LEQUAL) must be called for
    // the instruction below to work.
    gl_Position = pos.xyww;
}
