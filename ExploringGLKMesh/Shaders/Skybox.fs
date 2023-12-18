#version 330 core

out vec4 fragColor;

uniform samplerCube cubeMap;

// Modern Hardware supports cubemap textures out-of-the-box
// using the 3D coordinates as a direction vector to
// access the cubemap texture.
smooth in vec3 texCoords;

void main(void)
{
    vec3 dir = normalize(texCoords);
	fragColor = texture(cubeMap, dir);
}
    
