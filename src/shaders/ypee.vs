#version 330 core
in vec3 vPos;
in vec3 vColor;
in vec2 vTexCoords;
in mat4 modelMat;

out vec4 color;
out vec2 texCoords;

uniform vec2 texSize;
uniform vec4 texRect;
uniform mat4 viewMat;
uniform mat4 projMat;

void main() {
    gl_Position = projMat * viewMat * vec4(vPos, 1.0);
    color = vec4(vColor, 1.0);
    vec4 texRectF = vec4(texRect.x, texSize.y - texRect.y - texRect.w, texRect.z, texRect.w);
    vec2 halfPixels = vec2(0.5, 0.5) / texSize;
    texRectF.x += halfPixels.x;
    texRectF.y += halfPixels.y;
    texRectF.z -= 2 * halfPixels.x;
    texRectF.w -= 2 * halfPixels.y;
    vec2 tTexCoords = vTexCoords * texRectF.zw / texSize;
    texCoords = texRectF.xy / texSize + tTexCoords;
}