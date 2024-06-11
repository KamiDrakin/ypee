#version 330 core

in vec3 vPos;
in vec3 vColor;
in vec2 vTexCoords;

in vec4 iColor;
in vec4 texRect;
in vec4 blendColor;
in mat4 modelMat;

out vec4 color;
out vec2 texCoords;
out vec4 fBlendColor;

uniform vec2 texSize;
uniform mat4 viewMat;
uniform mat4 projMat;

void main() {
    gl_Position = projMat * viewMat * modelMat * vec4(vPos, 1.0);
    color = iColor * vec4(vColor, 1.0);
    vec4 texRectF = vec4(0.0, 0.0, texSize);
    if (texRect.z > 0.0 && texRect.z > 0.0) {
        texRectF = vec4(texRect.x, texSize.y - texRect.y - texRect.w, texRect.z, texRect.w);
    }
    vec2 halfPixels = vec2(0.5, 0.5) / texSize;
    texRectF.x += halfPixels.x;
    texRectF.y += halfPixels.y;
    texRectF.z -= 2 * halfPixels.x;
    texRectF.w -= 2 * halfPixels.y;
    vec2 tTexCoords = vTexCoords * texRectF.zw / texSize;
    texCoords = texRectF.xy / texSize + tTexCoords;
    fBlendColor = blendColor;
}