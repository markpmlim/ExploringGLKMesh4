#version 330 core
out vec4 FragColor;

in vec3 Normal;         // In view space
in vec3 Position;

uniform samplerCube cubeMap;

uniform mat4 viewMatrix;

void main()
{
    // In view space, the position of the camera is at (0, 0, 0)
    // So the vector from the camera to the vertex is
    // a vector subtraction of (0,0,0) from Position.
    vec3 I = normalize(Position);
    vec3 R = reflect(I, normalize(Normal));
    // The direction vector must be in world space
    vec3 R1 = mat3(inverse(viewMatrix)) * R;
    FragColor = vec4(texture(cubeMap, R1).rgb, 1.0);
}
