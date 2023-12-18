#version 330 core
layout (location = 0) in vec3 aPosition;
layout (location = 1) in vec3 aNormal;

out vec3 Normal;        // In view space
out vec3 Position;

uniform mat4 projectionMatrix;
uniform mat4 modelMatrix;
uniform mat4 viewMatrix;
uniform mat3 normalMatrix;

void main()
{
    // Both normal and position transformed into view space.
    Normal = normalMatrix * aNormal;
    Position = vec3(viewMatrix * modelMatrix * vec4(aPosition, 1.0));
    gl_Position = projectionMatrix * viewMatrix * modelMatrix * vec4(aPosition, 1.0);
}
