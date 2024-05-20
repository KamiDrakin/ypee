#version 330 core

layout (location = 0) in vec3 vPos;
layout (location = 1) in vec3 vColor;
layout (location = 2) in vec2 vTexCoords;

out vec4 color;
out vec2 texCoords;

uniform vec2 frameScale;

void main() {
    gl_Position = vec4(frameScale * vPos.xy, 0.0, 1.0);
    color = vec4(vColor, 1.0);
    texCoords = vTexCoords; // slightly off i guess
}  